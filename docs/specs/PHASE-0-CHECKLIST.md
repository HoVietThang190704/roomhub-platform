# Phase 0 — Checklist & Hợp đồng kỹ thuật (Handoff cho thành viên dựng repo)

Tài liệu này quy định các thông số kỹ thuật cố định cho Giai đoạn 0 để các thành viên dựng 5 repo đồng bộ, tránh xung đột port, tên event và cấu trúc thư mục.

## 1. Danh sách 5 Repo GitHub cần tạo

| # | Tên repo (đề xuất) | Vai trò | Mount path trong platform |
|---|---|---|---|
| 1 | `roomhub-platform` | Repo tổng (docs, docker, workspace, submodules) | `/` |
| 2 | `roomhub-storefront` | Next.js + Tailwind + shadcn (khách thuê, 360° viewer) | `apps/storefront` |
| 3 | `roomhub-admin-web` | Next.js + Ant Design (Admin & Dashboard Chủ nhà) | `apps/admin-web` |
| 4 | `roomhub-api` | NestJS monorepo (Gateway + 5 microservices + Prisma) | `apps/api` |
| 5 | `roomhub-mobile` | Placeholder cho giai đoạn sau (chỉ cần README + `.gitignore`) | `apps/mobile` |

> **Lưu ý:** Chờ Chủ tịch xác nhận tên Organization / tài khoản GitHub trước khi tạo repo và push.

## 2. Phân bổ Port chuẩn (Local Development)

| Thành phần | Port | Ghi chú |
|---|---|---|
| `storefront` | `3000` | Next.js App Router |
| `admin-web` | `3001` | Next.js App Router + Ant Design |
| `api-gateway` | `4000` | Điểm vào duy nhất từ FE (`/api/v1/*`) |
| `identity-service` | `4001` | Auth, RBAC (`TENANT`, `LANDLORD`, `ADMIN`), KYC |
| `listing-service` | `4002` | Building, Room, Amenity, Media/360, Geo search |
| `booking-service` | `4003` | ViewingSlot, Booking, Hold TTL (Redis) |
| `payment-service` | `4004` | payOS, Deposit, Commission, PlatformSetting |
| `notification-service` | `4005` | Email/SMS/Zalo, Socket.IO realtime |
| PostgreSQL (PostGIS) | `5432` | Container `roomhub-postgres` |
| Redis | `6379` | Container `roomhub-redis` |
| RabbitMQ (AMQP / UI) | `5672` / `15672` | Container `roomhub-rabbitmq` |

## 3. Quy ước Route tại `api-gateway`

- `/api/v1/auth/*`, `/api/v1/users/*`, `/api/v1/landlords/*` → `identity-service`
- `/api/v1/buildings/*`, `/api/v1/rooms/*`, `/api/v1/amenities/*` → `listing-service`
- `/api/v1/viewings/*`, `/api/v1/bookings/*` → `booking-service`
- `/api/v1/payments/*`, `/api/v1/webhooks/payos`, `/api/v1/settings/*`, `/api/v1/commissions/*` → `payment-service`
- `/api/v1/notifications/*` + Socket.IO `/ws` → `notification-service`

## 4. Hợp đồng Event bất đồng bộ (RabbitMQ)

Exchange chuẩn: `roomhub.events` (type `topic`, durable).

| Routing Key | Publisher | Consumers | Payload tối thiểu |
|---|---|---|---|
| `booking.created` | `booking-service` | `notification-service`, `listing-service` | `{ bookingId, roomId, tenantId, landlordId, status, holdExpiresAt }` |
| `deposit.paid` | `payment-service` | `booking-service`, `notification-service` | `{ bookingId, paymentId, orderCode, amount, paidAt }` |
| `booking.confirmed` | `booking-service` | `payment-service` (ghi Commission), `listing-service`, `notification-service` | `{ bookingId, roomId, landlordId, firstMonthRent, confirmedAt }` |
| `booking.cancelled` | `booking-service` | `listing-service` (nhả phòng), `payment-service`, `notification-service` | `{ bookingId, roomId, reason, cancelledBy }` |
| `viewing.scheduled` | `booking-service` | `notification-service` | `{ viewingSlotId, roomId, tenantId, landlordId, scheduledAt }` |

## 5. Checklist thực thi Giai đoạn 0

### A. Repo tổng (`roomhub-platform`)
- [ ] Tạo 5 repo trên GitHub theo tên Chủ tịch duyệt.
- [ ] Push skeleton từ `E:\Workspace\DuAnCaNhan\roomhub-platform` lên `roomhub-platform` (`main`).
- [ ] Chạy `docker compose -f infrastructure/docker/docker-compose.yml up -d` và xác nhận 3 container `healthy`.
- [ ] Kiểm tra 5 schema (`identity`, `listing`, `booking`, `payment`, `notification`) và extension `postgis` trong PostgreSQL.

### B. Submodule `apps/api` (`roomhub-api`)
- [ ] Khởi tạo NestJS monorepo (tham khảo `sushi-platform/apps/api`):
  - `apps/`: `api-gateway`, `identity-service`, `listing-service`, `booking-service`, `payment-service`, `notification-service`
  - `libs/`: `common`, `contracts`
  - `prisma/`: schema khởi tạo theo `docs/erd/ERD.md`
- [ ] Mỗi service có endpoint `GET /health` trả `{ status: "ok", service: "<name>" }`.
- [ ] Thiết lập GitHub Actions CI: `pnpm lint`, `pnpm typecheck`, `pnpm test`.

### C. Submodule `apps/storefront` (`roomhub-storefront`)
- [ ] Khởi tạo Next.js (App Router, TypeScript) + Tailwind CSS + shadcn/ui.
- [ ] Cài sẵn `TanStack Query`, `zustand`, `react-hook-form`, `zod`, `socket.io-client`.
- [ ] Quy ước bắt buộc: Pannellum (360°) chỉ nạp lười (`next/dynamic` với `ssr: false`); **không** cài `three` ở MVP.
- [ ] Thiết lập GitHub Actions CI: `pnpm lint`, `pnpm typecheck`, `pnpm build`.

### D. Submodule `apps/admin-web` (`roomhub-admin-web`)
- [ ] Khởi tạo Next.js (App Router, TypeScript) + Ant Design + TanStack Query + `zod` + `socket.io-client`.
- [ ] Dựng khung layout phân quyền cho 2 vai trò: `ADMIN` và `LANDLORD`.
- [ ] Thiết lập GitHub Actions CI: `pnpm lint`, `pnpm typecheck`, `pnpm build`.

### E. Gắn Submodule & Kiểm tra đầu cuối
- [ ] Xoá các thư mục placeholder rỗng trong `roomhub-platform/apps/`.
- [ ] Gắn 4 submodule bằng `git submodule add`.
- [ ] Thử clone mới ở thư mục tạm: `git clone --recurse-submodules <url-roomhub-platform>` và xác nhận chạy được toàn bộ.
