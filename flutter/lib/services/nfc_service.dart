import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';

enum NfcReadFailureReason { unsupported, disabled, tagNotReadable, sessionError }

class NfcReadFailure implements Exception {
  const NfcReadFailure(this.reason, this.message);

  final NfcReadFailureReason reason;
  final String message;

  @override
  String toString() => message;
}

/// 一次掃描讀到的原始 tag 資訊：硬體 UID（用冒號分隔的十六進位字串）與
/// 這張卡片支援的技術列表（例如 ["android.nfc.tech.NfcA", "android.nfc.tech.IsoDep"]）。
class NfcTagResult {
  const NfcTagResult({required this.uidHex, required this.techList});

  final String uidHex;
  final List<String> techList;
}

/// 封裝 NFC 掃描流程：檢查裝置支援度 → 開始 session → 讀到卡片後回傳 UID → 停止 session。
///
/// 注意：這張卡片實測回報的是 ISO14443-4（Type A / IsoDep），不是 NTAG215 那種
/// ISO14443-3A / Type 2，所以這裡不使用 MifareUltralight 相關 API 去讀卡
/// （MifareUltralightAndroid.from(tag) 對這種卡片會拿到 null），
/// 而是直接用 NfcTagAndroid.from(tag) 取得 Android 平台內建、跟技術類型無關的 id 和 techList。
///
/// iOS 這邊卡片是用 ISO7816 協定讀（Iso7816Ios），跟 Android 不同的是：
/// iOS 偵測 ISO7816 卡片前，系統會先拿 Info.plist 裡宣告的 AID
/// （com.apple.developer.nfc.readersession.iso7816.select-identifiers）依序對卡片
/// 送 SELECT，只有比對成功的卡片才會觸發 onDiscovered——AID 沒填對，iOS 端會完全
/// 偵測不到這張卡片，這點跟 Android「不管卡片內容直接拿到原始 tag」的行為不一樣。
class NfcService {
  Future<NfcAvailability> checkAvailability() {
    return NfcManager.instance.checkAvailability();
  }

  /// 開始一次 NFC 掃描，讀到第一張卡片後自動停止 session 並回傳結果。
  Future<NfcTagResult> readOnce() async {
    final availability = await NfcManager.instance.checkAvailability();
    if (availability == NfcAvailability.unsupported) {
      throw const NfcReadFailure(NfcReadFailureReason.unsupported, '這台裝置不支援 NFC 功能。');
    }
    if (availability == NfcAvailability.disabled) {
      throw const NfcReadFailure(NfcReadFailureReason.disabled, '請先到系統設定開啟 NFC 功能，再重新掃描。');
    }

    final completer = Completer<NfcTagResult>();

    Future<void> onDiscovered(NfcTag tag) async {
      final result = switch (defaultTargetPlatform) {
        TargetPlatform.android => _readAndroidTag(tag),
        TargetPlatform.iOS => _readIosTag(tag),
        _ => null,
      };

      if (result == null) {
        developer.log('偵測到卡片，但無法解析為已知的 tag 類型', name: 'NfcService');
        if (!completer.isCompleted) {
          completer.completeError(
            const NfcReadFailure(NfcReadFailureReason.tagNotReadable, '讀取到卡片，但無法識別這張卡片的類型。'),
          );
        }
      } else {
        developer.log('techList: ${result.techList}', name: 'NfcService');
        developer.log('UID: ${result.uidHex}', name: 'NfcService');
        if (!completer.isCompleted) {
          completer.complete(result);
        }
      }

      await NfcManager.instance.stopSession();
    }

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443},
        onDiscovered: onDiscovered,
      );
    } catch (e) {
      if (!completer.isCompleted) {
        completer.completeError(NfcReadFailure(NfcReadFailureReason.sessionError, 'NFC 讀取失敗：$e'));
      }
    }

    return completer.future;
  }

  NfcTagResult? _readAndroidTag(NfcTag tag) {
    final androidTag = NfcTagAndroid.from(tag);
    if (androidTag == null) return null;
    return NfcTagResult(uidHex: _formatUid(androidTag.id), techList: androidTag.techList);
  }

  NfcTagResult? _readIosTag(NfcTag tag) {
    final iso7816Tag = Iso7816Ios.from(tag);
    if (iso7816Tag == null) return null;
    return NfcTagResult(
      uidHex: _formatUid(iso7816Tag.identifier),
      techList: ['iso7816 (AID: ${iso7816Tag.initialSelectedAID})'],
    );
  }

  String _formatUid(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':').toUpperCase();
  }

  /// 讀取流程結束（不論成功、失敗或使用者離開畫面）都應該呼叫這個方法，
  /// 避免 NFC session 一直卡著。重複呼叫或目前沒有 session 都是安全的。
  Future<void> stopSession() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {
      // 沒有進行中的 session 時 stopSession 可能會丟例外，這裡忽略即可。
    }
  }
}
