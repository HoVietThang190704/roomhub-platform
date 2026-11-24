# RoomHub - Nền tảng booking phòng có tham quan 360°

Tham khảo kiến trúc: `sushi-platform` (pnpm monorepo, NestJS microservices, Next.js, Prisma/PostgreSQL, Redis, RabbitMQ, Socket.IO, Cloudinary).

## 1. Quyết định đã chốt
- Mô hình: nền tảng trung gian, thu hoa hồng trên mỗi booking thành công.
- Loại phòng: phòng trọ, căn hộ dịch vụ, thuê dài hạn cao cấp.
- Tham quan: ảnh 360° (Pannellum / Photo Sphere Viewer), hotspot chuyển cảnh.
- Đặt cọc online: bật/tắt và cấu hình trong Admin (toàn hệ thống, theo loại phòng, theo chủ nhà).

- Hoa hồng: tính trên **tiền thuê tháng đầu** (`commission = firstMonthRent × commission.rate`), ghi nhận khi booking `CONFIRMED`. Tỷ lệ mặc định cấu hình ở Admin, có thể ghi đè theo chủ nhà hoặc loại phòng (giá trị mặc định chưa chốt).
- Cổng thanh toán: **payOS** (VietQR, chuyển khoản ngân hàng). Tạo link thanh toán bằng `orderCode` duy nhất, nhận webhook xác nhận và kiểm chữ ký bằng Checksum Key. Cần Client ID, API Key, Checksum Key lấy từ kênh thanh toán payOS. Lưu ở biến môi trường, không đưa vào mã nguồn. Tra cứu trạng thái qua API payOS để đối chiếu khi webhook bị lỡ. Hoàn cọc làm thủ công hoặc chi hộ (payout) theo chính sách payOS.
- Cần xác minh với tài liệu payOS hiện hành trước khi lập trình (tên trường, thời hạn link, phí, hỗ trợ hoàn tiền).

## 2. Cấu trúc repo tổng + submodule (theo sushi-platform)
`roomhub-platform` là **repo tổng** (umbrella), chỉ chứa docs, infrastructure, `pnpm-workspace.yaml`, `.env.example`, `.gitmodules`. Mỗi app là một **repo con độc lập**, gắn bằng git submodule vào `apps/`:

| Path | Repo con (đặt tên đề xuất) |
|---|---|
| `apps/storefront` | `roomhub-storefront` |
| `apps/admin-web` | `roomhub-admin-web` |
| `apps/api` | `roomhub-api` (NestJS microservices, gồm các service bên dưới) |
| `apps/mobile` | `roomhub-mobile` (giai đoạn sau) |

Repo tổng ghim commit của từng submodule; mỗi repo con có CI, versioning và quyền truy cập riêng. Cần tạo các repo con trên GitHub trước, rồi `git submodule add <url> apps/<tên>`.

Cấu trúc thư mục:
```
roomhub/
  apps/
    storefront/        Next.js + Tailwind + shadcn: tìm phòng, trang phòng 360°, đặt lịch/cọc
    admin-web/         Next.js + Ant Design: admin và dashboard chủ nhà
    api/
      apps/api-gateway/        Cổng vào, auth proxy, rate limit
      apps/identity-service/   User, vai trò: TENANT / LANDLORD / ADMIN, KYC chủ nhà
      apps/listing-service/    Building, Room, Amenity, Media(360), Availability, tìm kiếm
      apps/booking-service/    Lịch xem phòng, Booking, hợp đồng, trạng thái
      apps/payment-service/    Cọc, hoa hồng, hoàn tiền, đối soát, cấu hình cọc
      apps/notification-service/ Email/SMS/Zalo, WebSocket realtime
      libs/common, libs/contracts
      prisma/
    mobile/            giai đoạn sau
  infrastructure/docker  postgres(+PostGIS), redis, rabbitmq
  docs/
```
Mỗi service sở hữu schema riêng. Giao tiếp đồng bộ qua HTTP, bất đồng bộ qua RabbitMQ (`booking.created`, `deposit.paid`, `booking.cancelled`).

## 3. Mô hình dữ liệu cốt lõi
- `User(role)`, `LandlordProfile(kycStatus, commissionRate?)`
- `Building(address, geo)`, `Room(type, price, area, status)`, `Amenity`
- `RoomMedia(kind: PHOTO|PANORAMA, url, order)`, `PanoScene(roomId, imageUrl, hotspots JSON[{yaw,pitch,targetSceneId}])`
- `Availability(roomId, from, to)`
- `ViewingSlot`, `Booking(status: PENDING|DEPOSIT_PENDING|CONFIRMED|CANCELLED|COMPLETED)`
- `Payment(bookingId, amount, provider, status)`, `Commission(bookingId, rate, amount)`
- `PlatformSetting` (key/value, có phạm vi):
  - `deposit.enabled`, `deposit.mode` (PERCENT|FIXED), `deposit.value`
  - `deposit.hold_hours`, `deposit.refund_policy`, `commission.rate`
  - ghi đè theo `roomType` hoặc `landlordId`

## 4. Luồng cọc theo cấu hình admin
1. Tenant chọn phòng, bấm "Đặt phòng".
2. `booking-service` hỏi `payment-service` cấu hình hiệu lực (ưu tiên: landlord > roomType > global).
3. Nếu `deposit.enabled=false`: Booking sang `CONFIRMED` hoặc chờ chủ nhà duyệt.
4. Nếu bật: tạo `Payment`, tạo link payOS (`paymentLinkId`, `orderCode`), giữ phòng `hold_hours` (Redis TTL).
5. Webhook xác nhận (kiểm chữ ký, idempotent) phát `deposit.paid`, Booking `CONFIRMED`, ghi `Commission`, thông báo realtime.
6. Hết hạn hoặc huỷ: nhả phòng, hoàn cọc theo chính sách.

## 5. Tham quan 360°
- Chủ nhà tải ảnh equirectangular lên Cloudinary/R2, gắn hotspot bằng trình chỉnh sửa trong dashboard.
- Storefront nạp lười Pannellum chỉ khi bấm "Xem 360°"; ảnh dự phòng cho máy yếu; nén nhiều độ phân giải.
- Mở rộng sau: mặt bằng 3D kiểu Casa Serra.
- **three.js:** MVP không dùng (Pannellum đủ). Giai đoạn 4 dùng three.js cho mặt bằng 3D / trang giới thiệu toà nhà; nạp bằng `next/dynamic` (`ssr:false`), chỉ khi người dùng bấm "Xem 3D", luôn có ảnh tĩnh dự phòng và tự hạ chất lượng trên máy yếu.

## 6. Lộ trình
| GĐ | Nội dung |
|---|---|
| 0 | PRD, ERD, UX wireframe, thiết lập monorepo, Docker, CI |
| 1 | identity, listing, storefront tìm phòng, trang phòng 360°, dashboard chủ nhà |
| 2 | booking, lịch xem phòng, notification realtime |
| 3 | payment + cấu hình cọc ở admin, tích hợp payOS, hoa hồng, đối soát |
| 4 | KYC, review, báo cáo, tối ưu hiệu năng, kiểm thử E2E |

## 7. Rủi ro
Chủ nhà thiếu ảnh 360° (cần gói chụp hộ); lừa đảo khi nhận cọc (KYC, giữ tiền trung gian); webhook thanh toán trùng (idempotency); hiệu năng mobile; tuân thủ pháp lý (hợp đồng thuê, thuế, dữ liệu cá nhân).
