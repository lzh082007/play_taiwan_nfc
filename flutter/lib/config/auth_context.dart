/// 目前後端還沒接登入驗證，所有需要「操作者身分」的 API 都用這裡的值代替
/// （見 docs/NFC_Flutter_Integration_Spec.md 第八節）。
///
/// 之後正式接上 JWT 後，`currentAuId` 會改成從登入 Token 解析取得，
/// 只要改這一個地方，不用每個呼叫點都改。
class AuthContext {
  AuthContext._();

  /// 測試用遊客 au_id，目前無外鍵檢查，先寫死。
  static const int currentAuId = 2;
}
