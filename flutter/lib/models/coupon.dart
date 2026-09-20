/// 優惠券物件，格式定義見 docs/NFC_Flutter_Integration_Spec.md 第六節。
class Coupon {
  const Coupon({
    required this.couponId,
    required this.sId,
    required this.couponCode,
    required this.couponName,
    required this.discountCommodity,
    required this.discountType,
    required this.discountValue,
    required this.validFrom,
    required this.validTo,
    required this.status,
  });

  final int couponId;
  final int sId;
  final String couponCode;
  final String couponName;
  final String discountCommodity;

  /// `percent`（百分比折扣）或 `amount`（固定金額折抵）。
  final String discountType;
  final num discountValue;
  final DateTime? validFrom;
  final DateTime? validTo;

  /// `active`（上架中）/ `inactive`（已下架）。
  final String status;

  bool get isActive => status == 'active';

  /// 折扣內容的顯示文字，例如「折100」或「9折」。
  String get discountLabel {
    return discountType == 'percent' ? '$discountValue折' : '折抵 $discountValue 元';
  }

  factory Coupon.fromJson(Map<String, dynamic> json) {
    return Coupon(
      couponId: json['coupon_id'] as int,
      sId: json['s_id'] as int,
      couponCode: json['coupon_code'] as String,
      couponName: json['coupon_name'] as String,
      discountCommodity: json['discount_commodity'] as String,
      discountType: json['discount_type'] as String,
      discountValue: json['discount_value'] as num,
      validFrom: _parseDateTime(json['valid_from']),
      validTo: _parseDateTime(json['valid_to']),
      status: json['status'] as String,
    );
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value == null) return null;
    return DateTime.parse(value as String);
  }
}
