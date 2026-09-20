import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// NFC 硬體 UID → 後端（Neo4j）uid 的對照表。
///
/// 對照表存在 [assetPath] 指到的 JSON 檔裡，格式是單純的
/// `{"硬體UID": "neo4j uuid"}`，key 要跟 [NfcTagResult.uidHex]（例如
/// `"04:A1:B2:C3"`，冒號分隔的大寫十六進位）完全一致才會比對到。
///
/// 第一次呼叫 [resolveNeo4jUuid] 時才會讀檔並快取在記憶體，之後重複查詢
/// 不會再重新讀取 asset。
class NfcUidMappingService {
  NfcUidMappingService({this.assetPath = 'assets/nfc_uid_mapping.json'});

  final String assetPath;

  Map<String, String>? _cache;

  Future<Map<String, String>> _loadMapping() async {
    final cached = _cache;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final mapping = decoded.map((key, value) => MapEntry(key, value as String));

    _cache = mapping;
    return mapping;
  }

  /// 用掃描到的硬體 UID 查對應的 Neo4j uuid。
  ///
  /// 查不到（對照表裡沒有這張卡片）回傳 null——呼叫端應該把這種情況當成
  /// 「這張卡片還沒有對應到任何地點」處理，效果等同後端查無資料。
  Future<String?> resolveNeo4jUuid(String hardwareUid) async {
    final mapping = await _loadMapping();
    return mapping[hardwareUid];
  }
}
