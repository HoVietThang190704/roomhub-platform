# RoomHub — Product Requirements Document (PRD)

- **Phiên bản:** 1.0 (Giai đoạn 0 — MVP Baseline)
- **Tài liệu liên quan:** [ARCHITECTURE.md](ARCHITECTURE.md) · [ERD.md](erd/ERD.md) · [PHASE-0-CHECKLIST.md](specs/PHASE-0-CHECKLIST.md)

---

## 1. Tổng quan sản phẩm & Mô hình kinh doanh

**RoomHub** là nền tảng trung gian kết nối người tìm thuê phòng (`TENANT`) và chủ nhà/đơn vị vận hành (`LANDLORD`) cho 3 phân khúc: **phòng trọ**, **căn hộ dịch vụ**, và **thuê dài hạn cao cấp**. Điểm khác biệt cốt lõi là **tham quan ảnh 360° từng phòng** ngay trên trình duyệt giúp giảm thời gian đi xem trực tiếp và tăng tỷ lệ chốt phòng.

### Quy tắc thương mại đã chốt
| Hạng mục | Quy định |
|---|---|
| Mô hình doanh thu | Hoa hồng trên mỗi booking thành công (`CONFIRMED`). |
| Công thức hoa hồng | `commission = firstMonthRent × commission.rate` (tính trên **tiền thuê tháng đầu**). |
| Tỷ lệ mặc định | `40%` (`0.40`), cấu hình tại Admin và hỗ trợ ghi đè theo `landlordId` hoặc `roomType`. |
| Đặt cọc online | **Bật/tắt linh hoạt ở Admin** (toàn hệ thống / theo loại phòng / theo chủ nhà). |
| Tách bạch dòng tiền | Tiền cọc là khoản giữ chỗ; hoa hồng tính độc lập trên tiền thuê tháng đầu. |
| Cổng thanh toán | **payOS** (VietQR / chuyển khoản ngân hàng). Hoàn cọc xử lý thủ công hoặc payout theo chính sách payOS. |

---

## 2. Phạm vi sản phẩm

### Trong phạm vi MVP (Giai đoạn 0 – 3)
- **GĐ 0:** PRD, ERD, dựng 5 repo (umbrella + submodules), Docker (PostGIS, Redis, RabbitMQ), khung 3 app, CI cơ bản.
- **GĐ 1:** `identity-service`, `listing-service`, Storefront tìm phòng + trang chi tiết có **Pannellum 360°** (nạp lười), Dashboard Chủ nhà (quản lý toà nhà/phòng, tải ảnh 360° & gắn hotspot).
- **GĐ 2:** `booking-service`, đặt lịch xem phòng (`ViewingSlot`), đặt phòng (`Booking`), giữ phòng theo Redis TTL, `notification-service` realtime (Socket.IO + Email/SMS/Zalo).
- **GĐ 3:** `payment-service`, cấu hình bật/tắt cọc & hoa hồng ở Admin (`PlatformSetting`), tích hợp payOS (tạo link thanh toán, webhook kiểm chữ ký + idempotency, đối soát trạng thái), ghi nhận `Commission`.

### Ngoài phạm vi MVP (Giai đoạn 4 trở đi)
- Mặt bằng 3D / trang giới thiệu toà nhà bằng **three.js** (nạp lười `ssr: false`, có ảnh tĩnh dự phòng và hạ chất lượng trên GPU yếu).
- Ứng dụng di động (`roomhub-mobile`).
- KYC nâng cao (eKYC tự động), hệ thống đánh giá (Review), báo cáo tài chính chuyên sâu, kiểm thử E2E tự động toàn diện.

---

## 3. Persona & Phân quyền (RBAC)

| Vai trò | Nhu cầu chính | Ứng dụng sử dụng |
|---|---|---|
| **TENANT** (Khách thuê) | Tìm phòng theo khu vực/giá/tiện ích, xem ảnh 360° mượt trên mobile, đặt lịch xem phòng, đặt phòng/cọc an toàn qua VietQR. | `roomhub-storefront` |
| **LANDLORD** (Chủ nhà / Quản lý toà nhà) | Đăng toà nhà & phòng, tải ảnh 360° + gắn hotspot chuyển cảnh, quản lý lịch trống, xác nhận lịch xem/booking, theo dõi doanh thu & hoa hồng. | `roomhub-admin-web` |
| **ADMIN** (Quản trị RoomHub) | Cấu hình bật/tắt cọc và tỷ lệ hoa hồng (Global / RoomType / Landlord), duyệt KYC chủ nhà, đối soát payOS & xử lý hoàn cọc/tranh chấp. | `roomhub-admin-web` |

---

## 4. Yêu cầu chức năng chi tiết

### 4.1. Tìm kiếm & Lọc phòng (`listing-service` + `storefront`)
- **US-01:** Là khách thuê, tôi muốn tìm phòng theo quận/thành phố, bán kính quanh tọa độ (PostGIS), khoảng giá, diện tích, loại phòng (`BOARDING`, `SERVICED_APT`, `LUXURY_LONG_TERM`) và tiện ích.
  - **AC:** Kết quả trả về có phân trang, ảnh đại diện, nhãn "Có 360°" nếu phòng có ít nhất 1 `PanoScene`, trạng thái phòng (`AVAILABLE`).
- **US-02:** Là khách thuê, tôi muốn xem chi tiết phòng gồm thông tin toà nhà, giá, diện tích, tiện ích, lịch trống (`Availability`) và thư viện ảnh.
  - **AC:** Trang chi tiết hỗ trợ SSR cho SEO, không tải thư viện 360° trong bundle ban đầu.

### 4.2. Tham quan 360° (`listing-service` + `storefront` + `admin-web`)
- **US-03:** Là khách thuê, tôi muốn bấm nút "Xem 360°" để xoay toàn cảnh phòng và bấm hotspot chuyển giữa các cảnh (phòng khách → phòng ngủ → WC).
  - **AC:** Trình xem Pannellum chỉ được nạp lười (`next/dynamic`, `ssr: false`) khi người dùng bấm mở; hỗ trợ gyro trên mobile; tự động rơi về ảnh tĩnh dự phòng nếu thiết bị không hỗ trợ WebGL hoặc mạng yếu.
- **US-04:** Là chủ nhà, tôi muốn tải ảnh equirectangular lên Cloudinary/R2 và chấm tọa độ (`yaw`, `pitch`) gắn hotspot nối sang cảnh khác trong Dashboard.
  - **AC:** Lưu được danh sách `PanoScene` và mảng `hotspots` JSON hợp lệ; chọn được cảnh mặc định (`isDefault`).

### 4.3. Lịch xem phòng & Đặt phòng (`booking-service`)
- **US-05:** Là khách thuê, tôi muốn đặt lịch xem phòng trực tiếp (`ViewingSlot`) theo khung giờ còn trống.
  - **AC:** Chủ nhà nhận thông báo realtime và có thể `CONFIRM` hoặc `CANCEL`.
- **US-06:** Là khách thuê, tôi muốn bấm "Đặt phòng" và chọn ngày dọn vào (`moveInDate`).
  - **AC:** Hệ thống hỏi cấu hình hiệu lực từ `payment-service` (ưu tiên `LANDLORD > ROOM_TYPE > GLOBAL`):
    - Nếu `deposit.enabled = false`: Booking chuyển `CONFIRMED` (hoặc `PENDING` chờ chủ nhà duyệt) mà không cần thanh toán online.
    - Nếu `deposit.enabled = true`: Tạo `Booking(DEPOSIT_PENDING)`, khóa giữ phòng bằng Redis TTL theo `deposit.hold_hours` và chuyển sang bước thanh toán payOS.
    - Khi hết `hold_hours` chưa thanh toán: tự động hủy booking và nhả phòng về `AVAILABLE`.

### 4.4. Thanh toán cọc payOS & Hoa hồng (`payment-service` + `admin-web`)
- **US-07:** Là khách thuê, tôi muốn thanh toán tiền cọc qua link/VietQR payOS và nhận xác nhận tức thì.
  - **AC:** Tạo `Payment` với `orderCode` duy nhất; webhook payOS được kiểm tra chữ ký bằng `PAYOS_CHECKSUM_KEY` và xử lý **idempotent** (webhook trùng không tạo trùng giao dịch/hoa hồng). Có job/API đối soát trạng thái từ payOS khi webhook bị lỡ.
- **US-08:** Là hệ thống, ngay khi booking chuyển sang `CONFIRMED`, tôi phải tự động tính và ghi nhận bảng `Commission`.
  - **AC:** `Commission.amount = firstMonthRent × rate` (với `rate` lấy theo thứ tự ưu tiên `LANDLORD > ROOM_TYPE > GLOBAL`, mặc định `0.40`).
- **US-09:** Là Admin, tôi muốn bật/tắt đặt cọc, chỉnh chế độ cọc (`PERCENT` / `FIXED`), thời gian giữ phòng (`hold_hours`), chính sách hoàn cọc và tỷ lệ hoa hồng theo 3 cấp phạm vi (`GLOBAL`, `ROOM_TYPE`, `LANDLORD`).
  - **AC:** Thay đổi có hiệu lực ngay cho các booking mới, không làm thay đổi ngược snapshot `firstMonthRent` / `depositAmount` của các booking đã tạo.

### 4.5. Quản trị & Thông báo realtime (`identity-service` + `notification-service`)
- **US-10:** Là chủ nhà, tôi muốn nộp hồ sơ KYC (`LandlordProfile`) để Admin duyệt trước khi tin đăng được gắn huy hiệu xác thực.
- **US-11:** Là khách thuê và chủ nhà, tôi muốn nhận thông báo realtime (Socket.IO) và qua Email/SMS/Zalo khi có sự kiện `booking.created`, `deposit.paid`, `booking.confirmed`, `booking.cancelled`, `viewing.scheduled`.

---

## 5. Yêu cầu phi chức năng (NFR)

1. **Hiệu năng & SEO:** Storefront đạt LCP < 2.5s trên 4G; không đưa `three.js` vào MVP; ảnh 360° nén nhiều độ phân giải và nạp lười.
2. **Bảo mật:** Phân quyền RBAC ở mọi endpoint qua `api-gateway` và service đích; mật khẩu băm `bcrypt`; tuyệt đối không commit `.env` hay khoá `PAYOS_*` vào Git.
3. **Tin cậy giao dịch:** Webhook thanh toán bắt buộc idempotent; giữ phòng chống đặt trùng bằng Redis distributed lock/TTL kết hợp kiểm tra trạng thái trong DB.
4. **Khả năng quan sát:** Mọi service có endpoint `GET /health` và log cấu trúc theo `requestId` / `bookingId`.

---

## 6. Chỉ số thành công (KPI MVP)

| Chỉ số | Mục tiêu MVP |
|---|---|
| Tỷ lệ khách mở xem 360° trên trang chi tiết phòng | ≥ 45% |
| Tỷ lệ chuyển đổi từ xem phòng → đặt lịch xem / đặt phòng | ≥ 8% |
| Tỷ lệ xử lý webhook payOS chính xác, không trùng | 100% |
| Thời gian phản hồi API tìm kiếm phòng (P95) | < 300ms |
