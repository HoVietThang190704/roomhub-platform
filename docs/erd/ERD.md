# RoomHub - Core ERD & Schema Specification

Mỗi microservice sở hữu một PostgreSQL schema độc lập trong database `roomhub` (khởi tạo bởi `infrastructure/docker/init-db/01-init-schemas.sql`). Tham chiếu giữa các schema dùng UUID (không tạo foreign key cứng xuyên schema).

## 1. Tổng quan ERD

```mermaid
erDiagram
    %% Schema: identity
    User ||--o| LandlordProfile : "has (when LANDLORD)"

    %% Schema: listing
    Building ||--o{ Room : "contains"
    Room ||--o{ RoomMedia : "has media"
    Room ||--o{ PanoScene : "has 360 scenes"
    Room ||--o{ RoomAmenity : "has"
    Amenity ||--o{ RoomAmenity : "tagged on"
    Room ||--o{ Availability : "has windows"

    %% Schema: booking
    Room ||--o{ ViewingSlot : "scheduled for (soft ref)"
    Room ||--o{ Booking : "booked (soft ref)"

    %% Schema: payment
    Booking ||--o{ Payment : "paid by (soft ref)"
    Booking ||--o| Commission : "generates (soft ref)"

    User {
        uuid id PK
        string email UK
        string phone UK
        string passwordHash
        enum role "TENANT | LANDLORD | ADMIN"
        enum status "ACTIVE | SUSPENDED"
        datetime createdAt
    }

    LandlordProfile {
        uuid id PK
        uuid userId FK
        string fullName
        string idNumber
        enum kycStatus "PENDING | VERIFIED | REJECTED"
        decimal commissionRate "nullable override"
    }

    Building {
        uuid id PK
        uuid landlordId "ref identity.User"
        string name
        string address
        string district
        string city
        geography geo "PostGIS Point"
    }

    Room {
        uuid id PK
        uuid buildingId FK
        string code
        enum type "BOARDING | SERVICED_APT | LUXURY_LONG_TERM"
        bigint monthlyRent "VND"
        float areaSqm
        enum status "AVAILABLE | HELD | OCCUPIED | HIDDEN"
    }

    RoomMedia {
        uuid id PK
        uuid roomId FK
        enum kind "PHOTO | PANORAMA"
        string url
        string thumbnailUrl
        int sortOrder
    }

    PanoScene {
        uuid id PK
        uuid roomId FK
        string title
        string imageUrl "equirectangular"
        jsonb hotspots "[{yaw, pitch, label, targetSceneId}]"
        boolean isDefault
    }

    Amenity {
        uuid id PK
        string code UK
        string name
        string icon
    }

    RoomAmenity {
        uuid roomId FK
        uuid amenityId FK
    }

    Availability {
        uuid id PK
        uuid roomId FK
        date availableFrom
        date availableTo "nullable"
    }

    ViewingSlot {
        uuid id PK
        uuid roomId "ref listing.Room"
        uuid tenantId "ref identity.User"
        datetime scheduledAt
        enum status "REQUESTED | CONFIRMED | COMPLETED | CANCELLED"
    }

    Booking {
        uuid id PK
        uuid roomId "ref listing.Room"
        uuid tenantId "ref identity.User"
        uuid landlordId "ref identity.User"
        date moveInDate
        bigint firstMonthRent "snapshot VND"
        bigint depositAmount "0 if deposit disabled"
        enum status "PENDING | DEPOSIT_PENDING | CONFIRMED | CANCELLED | COMPLETED"
        datetime holdExpiresAt "nullable"
    }

    Payment {
        uuid id PK
        uuid bookingId "ref booking.Booking"
        bigint orderCode UK "payOS unique int"
        string paymentLinkId
        bigint amount "VND"
        string provider "PAYOS"
        enum status "PENDING | PAID | CANCELLED | EXPIRED | REFUNDED"
        datetime paidAt "nullable"
    }

    Commission {
        uuid id PK
        uuid bookingId UK "ref booking.Booking"
        decimal rate "e.g. 0.40"
        bigint baseAmount "firstMonthRent"
        bigint amount "baseAmount * rate"
        enum status "ACCRUED | SETTLED | VOIDED"
    }

    PlatformSetting {
        uuid id PK
        string key "e.g. deposit.enabled, commission.rate"
        jsonb value
        enum scopeType "GLOBAL | ROOM_TYPE | LANDLORD"
        string scopeId "nullable"
    }
```

## 2. Quy tắc nghiệp vụ dữ liệu bắt buộc

1. **Hoa hồng (Commission):**
   - Công thức: `amount = firstMonthRent × rate`.
   - Thời điểm ghi nhận: ngay khi `Booking` chuyển sang `CONFIRMED`.
   - Cọc (`depositAmount`) và hoa hồng (`Commission.amount`) là hai khoản độc lập.
2. **Độ ưu tiên cấu hình `PlatformSetting`:**
   - Khi tra cứu `deposit.*` hoặc `commission.rate`, thứ tự ưu tiên:
     `LANDLORD (scopeId = landlordId)` → `ROOM_TYPE (scopeId = room.type)` → `GLOBAL`.
   - Các key chuẩn:
     - `deposit.enabled` (`boolean`)
     - `deposit.mode` (`"PERCENT" | "FIXED"`)
     - `deposit.value` (`number`)
     - `deposit.hold_hours` (`number`)
     - `deposit.refund_policy` (`object`)
     - `commission.rate` (`number`, mặc định `0.40`)
3. **Cấu trúc `PanoScene.hotspots`:**
   ```json
   [
     {
       "yaw": 120.5,
       "pitch": -5.0,
       "label": "Sang phòng ngủ",
       "targetSceneId": "uuid-of-target-scene"
     }
   ]
   ```
4. **Idempotency webhook thanh toán:**
   - Bảng `payment.WebhookEvent` (cần thêm khi vào GĐ 3) lưu `providerEventId` / `orderCode` + `checksum` để chống xử lý trùng webhook payOS.
