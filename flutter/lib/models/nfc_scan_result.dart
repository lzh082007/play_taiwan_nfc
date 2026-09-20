import 'coupon.dart';
import 'merchant_place.dart';

/// `GET /api/nfc/scan/{nfcUid}` 的回應內容，見
/// docs/NFC_Flutter_Integration_Spec.md 第四節。
class NfcScanResult {
  const NfcScanResult({required this.coupon, required this.merchantPlace, required this.isNewlyClaimed});

  final Coupon coupon;

  /// 若這個景點目前還沒有任何商家補充過資料，仍然會有 gov_name/gov_address
  /// 可以顯示；只有完全查不到景點節點時才會是 null。
  final MerchantPlace? merchantPlace;

  /// 這次呼叫是不是第一次幫這個使用者登記領取這張優惠券。
  /// 沒有帶 auId 查詢時固定是 false。
  final bool isNewlyClaimed;

  factory NfcScanResult.fromJson(Map<String, dynamic> json) {
    final merchantPlaceJson = json['merchant_place'] as Map<String, dynamic>?;
    return NfcScanResult(
      coupon: Coupon.fromJson(json['coupon'] as Map<String, dynamic>),
      merchantPlace: merchantPlaceJson == null ? null : MerchantPlace.fromJson(merchantPlaceJson),
      isNewlyClaimed: json['is_newly_claimed'] as bool,
    );
  }
}
