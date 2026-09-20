import '../models/nfc_scan_result.dart';
import '../services/nfc_api_client.dart';

export '../services/nfc_api_client.dart' show NfcApiException, NfcConnectionException, NfcResponseFormatException, NfcApiFailure;

/// 對應 docs/NFC_Flutter_Integration_Spec.md 描述的三支 NFC 優惠券 API：
/// 商家綁定貼紙、使用者掃描貼紙、核銷優惠券。
class NfcCouponRepository {
  NfcCouponRepository({NfcApiClient? apiClient}) : _apiClient = apiClient ?? NfcApiClient();

  final NfcApiClient _apiClient;

  /// 商家綁定 NFC 貼紙（功能一）。
  ///
  /// 失敗時丟出 [NfcApiFailure]；`isConflict`（HTTP 409）代表這張貼紙已經
  /// 綁定過優惠券了。
  Future<void> bindNfc({required String nfcUid, required int couponId}) async {
    await _apiClient.post('/api/merchant/nfc/bind', body: {'nfc_uid': nfcUid, 'coupon_id': couponId});
  }

  /// 使用者掃描 NFC 貼紙（功能二）：一次拿到商家/景點資訊 + 優惠券資訊，
  /// 帶 [auId] 時會自動幫使用者領取這張優惠券。
  ///
  /// 失敗時丟出 [NfcApiFailure]；`isNotFound`（HTTP 404）代表查無此貼紙
  /// 對應的優惠券。
  Future<NfcScanResult> scanNfc(String nfcUid, {int? auId}) async {
    final query = auId == null ? '' : '?auId=$auId';
    final result = await _apiClient.get('/api/nfc/scan/$nfcUid$query');
    if (result == null) {
      throw const NfcResponseFormatException('伺服器回應成功，但缺少 Result 內容。');
    }
    return NfcScanResult.fromJson(result);
  }

  /// 核銷優惠券（功能三）。
  ///
  /// 失敗時丟出 [NfcApiFailure]；`isConflict`（HTTP 409）代表這張優惠券
  /// 尚未領取、或已經核銷過了。
  Future<void> redeemCoupon({required int couponId, required int auId}) async {
    await _apiClient.post('/api/coupons/$couponId/redeem', body: {'au_id': auId});
  }
}
