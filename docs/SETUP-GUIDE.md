# Hướng dẫn dựng repo (Handoff cho thành viên thực hiện)

> Tài liệu đi kèm: [Kiến trúc hệ thống](ARCHITECTURE.md) · [ERD & Schema](erd/ERD.md) · [Checklist GĐ 0 & Hợp đồng kỹ thuật](specs/PHASE-0-CHECKLIST.md)

## A. Các bước thực hiện

### 1. Tạo 5 repo trống trên GitHub
Tạo trên tài khoản / Organization do Chủ tịch chỉ định:
- `roomhub-platform` (repo tổng)
- `roomhub-storefront`
- `roomhub-admin-web`
- `roomhub-api`
- `roomhub-mobile`

### 2. Đẩy skeleton repo tổng lên `roomhub-platform`
Thực hiện tại `E:\Workspace\DuAnCaNhan\roomhub-platform`:
```powershell
git init -b main
git add .
git commit -m "chore: init roomhub platform skeleton"
git remote add origin https://github.com/<ORG>/roomhub-platform.git
git push -u origin main
```

### 3. Khởi tạo 4 repo con và gắn git submodule
Push commit đầu tiên (tối thiểu `README.md` + `.gitignore`) vào từng repo con, sau đó xoá 4 thư mục placeholder rỗng trong `apps/` rồi gắn submodule:
```powershell
Remove-Item -Recurse -Force apps\storefront, apps\admin-web, apps\api, apps\mobile
git submodule add https://github.com/<ORG>/roomhub-storefront.git apps/storefront
git submodule add https://github.com/<ORG>/roomhub-admin-web.git  apps/admin-web
git submodule add https://github.com/<ORG>/roomhub-api.git        apps/api
git submodule add https://github.com/<ORG>/roomhub-mobile.git     apps/mobile
git commit -m "chore: attach app submodules"
git push
```
Mẫu cấu hình xem tại `.gitmodules.example`.

### 4. Dựng nội dung từng app (tham khảo `E:\Workspace\DuAnCaNhan\sushi-platform`)
Thực hiện đầy đủ theo [docs/specs/PHASE-0-CHECKLIST.md](specs/PHASE-0-CHECKLIST.md):
- **storefront:** Next.js + TypeScript, Tailwind, shadcn/ui, TanStack Query, zustand, react-hook-form + zod, socket.io-client, Pannellum (nạp lười `ssr: false`). Không thêm `three.js` ở MVP.
- **admin-web:** Next.js + TypeScript, Ant Design, TanStack Query, zod, socket.io-client.
- **api:** NestJS monorepo gồm `api-gateway`, `identity-service`, `listing-service`, `booking-service`, `payment-service`, `notification-service`; `libs/common`, `libs/contracts`; Prisma theo `docs/erd/ERD.md`, RabbitMQ, Redis, JWT, Cloudinary, class-validator.

### 5. Chạy hạ tầng local (Docker)
```powershell
Copy-Item .env.example .env
docker compose -f infrastructure/docker/docker-compose.yml up -d
docker compose -f infrastructure/docker/docker-compose.yml ps
```
Script `infrastructure/docker/init-db/01-init-schemas.sql` tự động bật `pgcrypto`, `postgis` và tạo 5 schema + role tương ứng (`identity`, `listing`, `booking`, `payment`, `notification`).

## B. Quy ước Git & Bảo mật
- Nhánh: `main` (ổn định), `develop`, `feature/*`, `fix/*`. Commit theo **Conventional Commits**.
- **Tuyệt đối không commit** `.env` hay khoá bí mật (JWT, Cloudinary, payOS). Chỉ cập nhật `.env.example`.
- Repo tổng chỉ cập nhật con trỏ submodule sau khi PR ở repo con đã được merge.

## C. Definition of Done (Giai đoạn 0)
- 5 repo tạo xong, submodule gắn đúng, `git clone --recurse-submodules` hoạt động.
- `docker compose up -d` khởi chạy 3 container (`roomhub-postgres`, `roomhub-redis`, `roomhub-rabbitmq`) ở trạng thái `healthy`.
- Mỗi app có `/health` (API) hoặc trang khung (FE), lint và GitHub Actions CI chạy xanh.
- Prisma schema khởi tạo khớp với [docs/erd/ERD.md](erd/ERD.md).

## D. Lưu ý tích hợp payOS
Cần `PAYOS_CLIENT_ID`, `PAYOS_API_KEY`, `PAYOS_CHECKSUM_KEY` từ kênh thanh toán payOS. Lưu ở biến môi trường và đối chiếu tài liệu payOS hiện hành trước khi lập trình GĐ 3.
