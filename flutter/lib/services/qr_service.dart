import 'package:flutter/material.dart';

import '../pages/qr_scanner_page.dart';

/// 使用者取消掃描（未掃到任何 QR 碼就返回）時丟出。
class QrReadCancelled implements Exception {
  const QrReadCancelled();
}

/// 封裝 QR 掃描流程：開啟全螢幕相機頁 → 掃到第一個 QR 碼後回傳內容並自動關閉頁面。
class QrService {
  /// 開啟相機掃描頁並回傳掃到的 QR 內容字串。
  ///
  /// 使用者按返回沒掃到任何內容時丟出 [QrReadCancelled]。
  Future<String> scanOnce(BuildContext context) async {
    final result = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const QrScannerPage()));
    if (result == null) {
      throw const QrReadCancelled();
    }
    return result;
  }
}
