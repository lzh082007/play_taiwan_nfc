import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

/// NFC 優惠券 API 例外的共同基底，UI 層可以用 `is` / `switch` 分辨原因。
sealed class NfcApiException implements Exception {
  const NfcApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 連不到主機：DNS 失敗、connection refused、逾時...等。
/// 通常代表 Base URL 設錯、手機和電腦不同網路、或防火牆擋住 port。
class NfcConnectionException extends NfcApiException {
  const NfcConnectionException(super.message);
}

/// 主機有回應，但回應內容不是預期的格式（不是合法 JSON、缺少欄位...等）。
class NfcResponseFormatException extends NfcApiException {
  const NfcResponseFormatException(super.message);
}

/// 後端回應 `isSuccess: false` 時的商業邏輯錯誤，[statusCode] 對照
/// docs/NFC_Flutter_Integration_Spec.md 第二節的錯誤碼表（400/404/409/500...）。
/// [message] 是後端回傳、可以直接顯示給使用者看的錯誤說明。
class NfcApiFailure extends NfcApiException {
  const NfcApiFailure(this.statusCode, super.message);

  final int statusCode;

  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;
}

/// 呼叫 NFC 優惠券後端 API 的共用邏輯：送出 request、解開統一回應格式
/// `{ isSuccess, message, Result }`、把錯誤狀態碼轉成對應的例外。
class NfcApiClient {
  NfcApiClient({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _client;
  final String _baseUrl;

  static const Duration _timeout = Duration(seconds: 8);

  Future<Map<String, dynamic>?> get(String path) => _send('GET', path);

  Future<Map<String, dynamic>?> post(String path, {Object? body}) => _send('POST', path, body: body);

  Future<Map<String, dynamic>?> _send(String method, String path, {Object? body}) async {
    final uri = Uri.parse('$_baseUrl$path');

    final http.Response response;
    try {
      final request = http.Request(method, uri)..headers['Content-Type'] = 'application/json; charset=utf-8';
      if (body != null) {
        request.body = jsonEncode(body);
      }
      final streamed = await _client.send(request).timeout(_timeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw NfcConnectionException(
        '連線逾時，無法連到伺服器（$_baseUrl）。\n'
        '請確認：手機和電腦在同一個 Wi-Fi、Base URL 是否為電腦的區網 IP、'
        '電腦防火牆是否已放行這個 API 的 port。',
      );
    } on SocketException catch (e) {
      throw NfcConnectionException('無法連線到伺服器（$_baseUrl）：${e.message}\n請確認後端服務是否已啟動、Base URL 是否正確。');
    } on http.ClientException catch (e) {
      throw NfcConnectionException('連線發生錯誤：${e.message}');
    }

    final Object? decoded;
    try {
      decoded = response.bodyBytes.isEmpty ? null : jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException catch (e) {
      throw NfcResponseFormatException('伺服器有回應，但內容不是合法的 JSON：${e.message}');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const NfcResponseFormatException('伺服器有回應，但格式不是預期的物件（JSON object）。');
    }

    final isSuccess = decoded['isSuccess'] as bool?;
    final message = decoded['message'] as String? ?? '';

    if (isSuccess == null) {
      throw const NfcResponseFormatException('伺服器有回應，但缺少 isSuccess 欄位。');
    }

    if (!isSuccess) {
      throw NfcApiFailure(response.statusCode, message);
    }

    return decoded['Result'] as Map<String, dynamic>?;
  }
}
