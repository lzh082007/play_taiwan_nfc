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
/// 貼紙規格是 NTAG215（ISO14443-3A / Type 2）。
/// Android 這邊直接用 NfcTagAndroid.from(tag) 取得平台內建、跟技術類型無關的 id 和 techList。
///
/// iOS 這邊 NTAG215 屬於 MiFare family，用 MiFareIos.from(tag) 讀（不是 Iso7816Ios）。
/// 這類標籤 iOS 偵測時不需要在 Info.plist 宣告 AID 就能觸發 onDiscovered，
/// 跟通用 ISO7816 智慧卡（例如身分證、護照那類需要先 SELECT AID 才會被偵測到的卡片）不同。
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
    final miFareTag = MiFareIos.from(tag);
    if (miFareTag == null) return null;
    return NfcTagResult(uidHex: _formatUid(miFareTag.identifier), techList: const ['MiFare (NTAG215)']);
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
