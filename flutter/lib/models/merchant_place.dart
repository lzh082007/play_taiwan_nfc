/// 商家自己補充/覆蓋過的最新資訊（版本鏈目前生效版本）。
///
/// 欄位不是固定 schema，目前後端只會寫入 name/address/description/phone/
/// website/openingHours 這幾個，其餘是版本控制用的欄位。App 端用欄位存不存在
/// （這裡等同於：值是不是 null）來決定要不要顯示，而不是預期一定有值。
class MerchantOverride {
  const MerchantOverride({
    this.name,
    this.address,
    this.description,
    this.phone,
    this.website,
    this.openingHours,
  });

  final String? name;
  final String? address;
  final String? description;
  final String? phone;
  final String? website;
  final String? openingHours;

  factory MerchantOverride.fromJson(Map<String, dynamic> json) {
    return MerchantOverride(
      name: json['name'] as String?,
      address: json['address'] as String?,
      description: json['description'] as String?,
      phone: json['phone'] as String?,
      website: json['website'] as String?,
      openingHours: json['opening_hours'] as String?,
    );
  }
}

/// 景點圖片，`description` 沒有說明文字時是 null。
class PlaceImage {
  const PlaceImage({required this.url, this.description});

  final String url;
  final String? description;

  factory PlaceImage.fromJson(Map<String, dynamic> json) {
    return PlaceImage(url: json['url'] as String, description: json['description'] as String?);
  }
}

/// 單日營業時段。Event（活動）類型的景點一定沒有這筆資料（空陣列）。
class OperatingHour {
  const OperatingHour({required this.dayOfWeek, required this.openTime, required this.closeTime});

  /// "Monday" ~ "Sunday"。
  final String dayOfWeek;

  /// "HH:MM:SS" 格式的字串。
  final String openTime;
  final String closeTime;

  factory OperatingHour.fromJson(Map<String, dynamic> json) {
    return OperatingHour(
      dayOfWeek: json['day_of_week'] as String,
      openTime: json['open_time'] as String,
      closeTime: json['close_time'] as String,
    );
  }
}

/// 景點的完整詳情，全部來自 Neo4j，格式定義見
/// docs/NFC_Flutter_Integration_Spec.md 第四節。
///
/// `gov_` 開頭的欄位是政府開放資料節點本身的內容，不會因商家編輯而改變；
/// [merchantOverride] 才是商家可以覆蓋的內容。
class MerchantPlace {
  const MerchantPlace({
    required this.uid,
    required this.identityLabels,
    required this.govName,
    required this.govDescription,
    required this.govAddress,
    required this.govLat,
    required this.govLon,
    required this.govStatus,
    required this.govPhone,
    required this.govWebsite,
    required this.govTicketInfo,
    required this.govTravelInfo,
    required this.categories,
    required this.city,
    required this.town,
    required this.images,
    required this.operatingHours,
    required this.hotelClasses,
    required this.merchantOverride,
  });

  final String uid;

  /// 景點在 Neo4j 裡的原始分類標籤（例如 Restaurant/Attraction/Hotel/Event，
  /// 或商家自建景點會是 MerchantPlace），可以用來決定 UI 要顯示餐廳、景點、
  /// 旅宿還是活動版型。
  final List<String> identityLabels;

  final String govName;
  final String govDescription;
  final String govAddress;

  /// 經緯度，可以直接拿去畫地圖標記；商家自建的景點（無政府座標）會是 null。
  final double? govLat;
  final double? govLon;

  /// 營業狀態文字（例如「營業中」），不是固定列舉值，也可能是空字串。
  final String govStatus;

  /// 只有 Attraction 類型景點通常才有值，其餘類型大多是 null。
  final String? govPhone;
  final String? govWebsite;

  /// 票價資訊／交通建議，可能是空字串。
  final String govTicketInfo;
  final String govTravelInfo;

  /// 景點分類，沒有分類則是空陣列。
  final List<String> categories;

  final String? city;
  final String? town;

  /// 景點圖片清單，沒有圖片是空陣列，請勿假設一定至少有一張。
  final List<PlaceImage> images;

  /// 每日營業時段。Event 類型一定是空陣列，其餘類型若資料集沒有營業時間
  /// 資料也會是空陣列。
  final List<OperatingHour> operatingHours;

  /// 旅宿類型（例如「一般旅館」），只有 Hotel 類型會有值，其餘類型固定是空陣列。
  final List<String> hotelClasses;

  /// 商家自己補充/覆蓋過的最新資訊，若商家從來沒有呼叫過「更新商家資料」API
  /// 會是 null。
  final MerchantOverride? merchantOverride;

  /// 名稱/介紹/地址優先顯示 [merchantOverride] 裡對應的欄位，沒有的話
  /// fallback 用 gov_ 開頭的政府開放資料。
  String get displayName => merchantOverride?.name ?? govName;
  String get displayDescription => merchantOverride?.description ?? govDescription;
  String get displayAddress => merchantOverride?.address ?? govAddress;
  String? get displayPhone => merchantOverride?.phone ?? govPhone;
  String? get displayWebsite => merchantOverride?.website ?? govWebsite;

  factory MerchantPlace.fromJson(Map<String, dynamic> json) {
    final overrideJson = json['merchant_override'] as Map<String, dynamic>?;
    final imagesJson = json['images'] as List<dynamic>;
    final operatingHoursJson = json['operating_hours'] as List<dynamic>;

    return MerchantPlace(
      uid: json['uid'] as String,
      identityLabels: (json['identity_labels'] as List<dynamic>).cast<String>(),
      govName: json['gov_name'] as String,
      govDescription: json['gov_description'] as String,
      govAddress: json['gov_address'] as String,
      govLat: (json['gov_lat'] as num?)?.toDouble(),
      govLon: (json['gov_lon'] as num?)?.toDouble(),
      govStatus: json['gov_status'] as String,
      govPhone: json['gov_phone'] as String?,
      govWebsite: json['gov_website'] as String?,
      govTicketInfo: json['gov_ticket_info'] as String,
      govTravelInfo: json['gov_travel_info'] as String,
      categories: (json['categories'] as List<dynamic>).cast<String>(),
      city: json['city'] as String?,
      town: json['town'] as String?,
      images: imagesJson.map((e) => PlaceImage.fromJson(e as Map<String, dynamic>)).toList(),
      operatingHours: operatingHoursJson.map((e) => OperatingHour.fromJson(e as Map<String, dynamic>)).toList(),
      hotelClasses: (json['hotel_classes'] as List<dynamic>).cast<String>(),
      merchantOverride: overrideJson == null ? null : MerchantOverride.fromJson(overrideJson),
    );
  }
}
