# NFC 商家優惠券功能 — Flutter 開發規格說明書

> **Version:** 1.1.0（2026-09-21 更新：`merchant_place` 擴充為完整景點詳情，見第四節）
> **Date:** 2026-09-20
> **對象：** Flutter App 開發人員（使用者端 App／商家端 App）
> **範圍：** NFC 貼紙綁定、掃描查詢、優惠券領取與核銷相關 API
> **後端狀態：** 第一階段開發中，**尚未接登入驗證**。所有需要「操作者身分」的 API，
> 目前都用 request 中明確帶入的 `au_id`（遊客）或 `s_id`（商家）代替，
> 之後正式接上 JWT 後，這些欄位會拿掉，改成從登入 Token 自動帶出——
> 屆時只有「誰在呼叫」的判斷方式改變，API 路徑與回應格式都不會變動，
> 請 Flutter 端先按照本文件開發，之後只要移除手動帶入 ID 的欄位即可。

---

## 一、名詞說明

| 名詞 | 說明 |
|------|------|
| `au_id` | 使用者（遊客）帳號流水號，對應 `auth` 表。之後會從登入 JWT 取得，目前先由 App 自己記住/帶入。 |
| `s_id` | 商家帳號流水號，對應 `store` 表。商家 App 登入後應該記住自己的 `s_id`。 |
| `nfc_uid` | NFC 貼紙本身的序號（貼紙晶片內建的 UID，掃描讀取到的字串），**不是**資料庫自動產生的值，由手機讀到什麼就傳什麼。 |
| `coupon_id` | 優惠券流水號，商家後台建立優惠券時由後端配發。 |
| `store_uid` | 商家綁定的景點在 Neo4j 圖資料庫裡的節點 UUID，用來查詢「商家/景點介紹資訊」，App 不需要自己組這個值，掃描 API 會直接回傳整理好的資料。 |

---

## 二、共用設定

- **Base URL（開發環境）**：`http://<後端主機>:5501`
- **Content-Type**：`application/json; charset=utf-8`
- **回應格式**：所有 API 統一回傳這個結構（跟其他既有模組一致）：
  ```json
  {
    "isSuccess": true,
    "message": "查詢成功",
    "Result": { /* 依 API 而定，可能是物件、陣列或 null */ }
  }
  ```
  - `isSuccess = false` 時，`message` 會是可以直接顯示給使用者看的錯誤說明。
  - 錯誤時的 HTTP status code：
    | Status | 情境 |
    |--------|------|
    | 400 | 缺少必填欄位或參數格式錯誤 |
    | 404 | 查無資料（例如 NFC 貼紙沒有綁定過優惠券） |
    | 409 | 商業邏輯衝突（例如貼紙重複綁定、優惠券已核銷過） |
    | 500 | 未預期的系統錯誤 |

---

## 三、功能一：商家綁定 NFC 貼紙（商家端 App）

商家用手機掃描到一張新的 NFC 貼紙後，呼叫這支 API 把貼紙跟指定的優惠券綁在一起。

### `POST /api/merchant/nfc/bind`

**Request Body**
```json
{
  "nfc_uid": "04A1B2C3D4E5",
  "coupon_id": 1
}
```

| 欄位 | 型別 | 必填 | 說明 |
|------|------|------|------|
| `nfc_uid` | string | ✅ | 手機讀到的 NFC 貼紙序號原始字串 |
| `coupon_id` | int | ✅ | 要綁定的優惠券 ID（商家需先透過優惠券 CRUD API 建立好優惠券，見第五節） |

**成功回應**
```json
{ "isSuccess": true, "message": "NFC 貼紙綁定成功", "Result": null }
```

**失敗情境**：同一張 `nfc_uid` 已經綁定過（不論綁定哪張優惠券），回傳 **HTTP 409**：
```json
{ "isSuccess": false, "message": "NFC 貼紙 04A1B2C3D4E5 已經綁定過優惠券", "Result": null }
```
→ UI 建議：提示商家「這張貼紙已經用過了，請換一張新的貼紙，或到優惠券管理頁面確認目前綁定狀況」。

---

## 四、功能二：使用者掃描 NFC 貼紙（使用者端 App）

這是整個 NFC 功能的核心 API。使用者用手機靠近店家的 NFC 貼紙，App 讀到 `nfc_uid` 後呼叫這支 API，
一次拿到「商家資訊」+「優惠券資訊」，並且（帶入 `auId` 時）自動幫使用者領取這張優惠券。

### `GET /api/nfc/scan/{nfcUid}?auId={auId}`

| 參數 | 位置 | 必填 | 說明 |
|------|------|------|------|
| `nfcUid` | path | ✅ | 手機讀到的 NFC 貼紙序號 |
| `auId` | query | 選填 | 目前登入使用者的 `au_id`。**不帶這個參數只會查詢資訊、不會寫入領取紀錄**（例如訪客未登入時可以先讓他看到優惠券內容，但不能先幫他登記領取）。 |

**範例呼叫**
```
GET /api/nfc/scan/04A1B2C3D4E5?auId=1001
```

**成功回應**（下面是真的用瑪莎園景觀餐廳這筆資料打出來的實際結果）
```json
{
  "isSuccess": true,
  "message": "查詢成功",
  "Result": {
    "coupon": {
      "coupon_id": 2,
      "s_id": 2,
      "coupon_code": "MASHA100",
      "coupon_name": "消費滿千折100",
      "discount_commodity": "全店餐點",
      "discount_type": "amount",
      "discount_value": 100.00,
      "valid_from": "2026-09-20T00:00:00",
      "valid_to": "2026-12-31T23:59:59",
      "status": "active"
    },
    "merchant_place": {
      "uid": "54b0afa1-860a-4586-a7ea-56b215a874ca",
      "identity_labels": ["Restaurant", "Place"],
      "gov_name": "瑪莎園景觀餐廳",
      "gov_description": "瑪莎園景觀餐廳位於玉井虎頭山，店內俯瞰玉井盆地及週圍群山，庭園優美並可攜帶寵物，假日人潮多，是玉井知名景點之一。",
      "gov_address": "沙田里沙田25-66號",
      "gov_lat": 23.12976,
      "gov_lon": 120.4831,
      "gov_status": "",
      "gov_phone": null,
      "gov_website": null,
      "gov_ticket_info": "",
      "gov_travel_info": "",
      "categories": ["旅遊服務站類"],
      "city": "台南市",
      "town": "玉井區",
      "images": [
        { "url": "https://may128.com/wp-content/uploads/2025/05/8.jpg", "description": null }
      ],
      "operating_hours": [],
      "hotel_classes": [],
      "merchant_override": null
    },
    "is_newly_claimed": true
  }
}
```

**欄位說明**

| 欄位 | 型別 | 說明 |
|------|------|------|
| `coupon` | object | 優惠券完整資訊，來自 MySQL。欄位定義見第六節「優惠券物件格式」。 |
| `merchant_place` | object \| null | 景點的完整詳情，**全部來自 Neo4j**。`gov_` 開頭的欄位是政府開放資料節點本身的內容，不會因商家編輯而改變；`merchant_override` 才是商家可以覆蓋的內容。 |
| `merchant_place.identity_labels` | string[] | 景點在 Neo4j 裡的原始分類標籤（例如 `Restaurant`/`Attraction`/`Hotel`/`Event`，或商家自建景點會是 `MerchantPlace`），可以用來決定 UI 要顯示餐廳、景點、旅宿還是活動版型。 |
| `merchant_place.gov_name` / `gov_description` / `gov_address` | string | 名稱／介紹文字／地址。 |
| `merchant_place.gov_lat` / `gov_lon` | double \| null | 經緯度，可以直接拿去畫地圖標記；商家自建的景點（無政府座標）會是 `null`。 |
| `merchant_place.gov_status` | string | 營業狀態文字（例如「營業中」），**不是固定列舉值**，資料集本身填什麼就是什麼，也可能是空字串（代表沒有資料），請勿寫死比對邏輯。 |
| `merchant_place.gov_phone` / `gov_website` | string \| null | 電話／官網，只有 Attraction 類型景點通常才有值，其餘類型大多是 `null`。 |
| `merchant_place.gov_ticket_info` / `gov_travel_info` | string | 票價資訊／交通建議，可能是空字串。 |
| `merchant_place.categories` | string[] | 景點分類（可能有多個），沒有分類則是空陣列。 |
| `merchant_place.city` / `town` | string \| null | 所屬縣市／鄉鎮市區。 |
| `merchant_place.images` | array | 景點圖片清單，每筆是 `{ "url": string, "description": string \| null }`，沒有圖片是空陣列，**請勿假設一定至少有一張**。 |
| `merchant_place.operating_hours` | array | 每日營業時段，每筆是 `{ "day_of_week": "Monday"~"Sunday", "open_time": "HH:MM:SS", "close_time": "HH:MM:SS" }`。**Event（活動）類型一定是空陣列**，其餘類型若資料集沒有營業時間資料也會是空陣列。 |
| `merchant_place.hotel_classes` | string[] | 旅宿類型（例如「一般旅館」），**只有 Hotel 類型會有值**，其餘類型固定是空陣列。 |
| `merchant_place.merchant_override` | object \| null | 商家自己補充/覆蓋過的最新資訊（版本鏈目前生效版本）。若商家從來沒有呼叫過「更新商家資料」API，這裡會是 `null`——**這時請 UI 改顯示 `gov_name`/`gov_description`/`gov_address` 這組政府開放資料當作顯示內容**，不要讓畫面整塊空白。裡面的欄位不是固定 schema，目前後端只會寫入 `name`/`address`/`description`/`phone`/`website`/`opening_hours` 這幾個，其餘是版本控制用的欄位（`source`/`submitted_by`/`version_no`），建議用欄位存不存在來決定要不要顯示。 |
| `is_newly_claimed` | bool | 這次呼叫是不是第一次幫這個使用者登記領取這張優惠券。`true` = 剛剛新增了一筆領取紀錄；`false` = 使用者之前已經領過了（沒有帶 `auId` 時固定是 `false`）。 |

> **顯示優先順序建議**：畫面上的商家名稱/介紹/地址，建議優先顯示 `merchant_override` 裡對應的欄位（若存在），沒有的話 fallback 用 `gov_name`/`gov_description`/`gov_address`。經緯度、圖片、分類、營業時間、旅宿類型這些目前**只有政府資料這一份**（商家還不能透過 API 編輯這些），固定顯示 `gov_lat`/`gov_lon`/`images`/`categories`/`operating_hours`/`hotel_classes` 即可。

**失敗情境**：查無此 `nfc_uid` 對應的優惠券，回傳 **HTTP 404**：
```json
{ "isSuccess": false, "message": "找不到 NFC 貼紙 04A1B2C3D4E5 對應的優惠券資料", "Result": null }
```
→ UI 建議：顯示「這張貼紙尚未啟用，請洽店家」。

---

## 五、功能三：核銷優惠券（使用者端 App，店員操作或使用者自己操作皆可）

使用者要在店內兌換優惠時呼叫，把優惠券標記為已使用。

### `POST /api/coupons/{couponId}/redeem`

| 參數 | 位置 | 必填 | 說明 |
|------|------|------|------|
| `couponId` | path | ✅ | 優惠券 ID，來自掃描結果的 `coupon.coupon_id` |

**Request Body**
```json
{ "au_id": 1001 }
```

**成功回應**
```json
{ "isSuccess": true, "message": "優惠券核銷成功", "Result": null }
```

**失敗情境**：這位使用者根本沒領過這張優惠券、或已經核銷過一次了，回傳 **HTTP 409**：
```json
{ "isSuccess": false, "message": "此優惠券尚未領取，或已經核銷過，無法重複核銷", "Result": null }
```
→ UI 建議：核銷按鈕按下去失敗時，直接顯示「這張優惠券已經使用過囉」。

---

## 六、優惠券物件格式（供參考）

以下是 `coupon` 物件在所有 NFC 相關 API 裡共用的欄位定義：

| 欄位 | 型別 | 說明 |
|------|------|------|
| `coupon_id` | int | 優惠券 ID |
| `s_id` | int | 所屬商家 ID |
| `coupon_code` | string | 優惠券代碼（商家自訂） |
| `coupon_name` | string | 優惠券名稱 |
| `discount_commodity` | string | 折扣品項說明 |
| `discount_type` | string | `percent`（百分比折扣）或 `amount`（固定金額折抵） |
| `discount_value` | decimal | 折扣數值（`discount_type=percent` 時代表折數/百分比數字；`amount` 時代表折抵金額） |
| `valid_from` / `valid_to` | datetime \| null | 生效/截止時間，`null` 代表沒有限制 |
| `status` | string | `active`（上架中）/ `inactive`（已下架）。**目前掃描 API 不會擋下 `inactive` 的優惠券**，若需要「已下架不能領取/核銷」的行為，請先跟後端確認是否要加這個檢查，或先在 App 端自行判斷 `status` 決定是否顯示領取/核銷按鈕。 |

商家後台建立/管理優惠券的 CRUD API（`api/merchant/coupons/*`）目前是給商家管理後台用的，
如果 Flutter 也要做商家端管理優惠券的畫面，需要的話我可以再補一份對應的規格文件。

---

## 七、完整流程示意

```
商家 App                後端 API                        使用者 App
   │                        │                                │
   │  建立優惠券（略，見商家後台文件）                          │
   │                        │                                │
   │  掃到 NFC 貼紙          │                                │
   ├─POST /merchant/nfc/bind──►                               │
   │◄──綁定成功────────────┤                                │
   │                        │                                │
   │                        │        使用者掃到同一張貼紙       │
   │                        │◄──GET /nfc/scan/{uid}?auId=──┤
   │                        ├──商家資訊+優惠券資訊─────────►│
   │                        │  （已自動登記領取紀錄）          │
   │                        │                                │
   │                        │      使用者到店要求兌換           │
   │                        │◄──POST /coupons/{id}/redeem──┤
   │                        ├──核銷成功─────────────────►│
```

---

## 八、之後接 JWT 時的變動預告

| 現在 | 之後 |
|------|------|
| `GET /api/nfc/scan/{nfcUid}?auId=1001` | `GET /api/nfc/scan/{nfcUid}`（`auId` 從 Header 的 `Authorization: Bearer <token>` 自動解析，不用帶在 URL） |
| `POST /api/coupons/{couponId}/redeem` body 帶 `{ "au_id": 1001 }` | body 拿掉 `au_id`，改由 Token 自動判斷 |
| `POST /api/merchant/nfc/bind` 目前不驗證是不是本人商家在操作 | 之後會驗證呼叫者的 Token 身分是否等於該優惠券所屬的商家 |

路徑、回應格式、錯誤碼在這次改動前後都不會變，Flutter 端建議把「取得目前使用者 ID」的邏輯
集中寫成一個 helper（例如 `AuthContext.currentAuId`），之後要把它從「App 內暫存值」換成
「解析 JWT 拿到的值」時，只要改這一個地方就好，不用每個呼叫點都改。

---

## 九、可直接拿來測試的資料

| 項目 | 值 |
|------|-----|
| 一個已存在的 Neo4j 景點 uid（瑪莎園景觀餐廳，Restaurant 類型） | `54b0afa1-860a-4586-a7ea-56b215a874ca` |
| 測試用 NFC 貼紙序號（自己編一個即可） | `NFC-TEST-0001` |
| 測試用遊客 au_id（目前無外鍵檢查，用假值即可） | `999` |

若需要商家端完整的優惠券建立/題庫管理 API 規格（給商家後台或商家 App 用），可以再另外提供一份文件。
