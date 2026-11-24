# RoomHub Platform (Repo tổng)

Nền tảng trung gian cho thuê phòng trọ, căn hộ dịch vụ và thuê dài hạn cao cấp, có tham quan ảnh 360° từng phòng, đặt cọc online qua payOS (Admin bật/tắt và cấu hình), hoa hồng tính trên tiền thuê tháng đầu.

Repo này là **repo tổng (umbrella)**: chỉ chứa tài liệu, hạ tầng Docker và cấu hình workspace. Mỗi ứng dụng là một **repo con độc lập (git submodule)** gắn trong `apps/`.

## Tài liệu chính
- Kiến trúc hệ thống: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- ERD & mô hình dữ liệu: [docs/erd/ERD.md](docs/erd/ERD.md)
- Hướng dẫn dựng repo (handoff): [docs/SETUP-GUIDE.md](docs/SETUP-GUIDE.md)
- Checklist GĐ 0 & hợp đồng kỹ thuật: [docs/specs/PHASE-0-CHECKLIST.md](docs/specs/PHASE-0-CHECKLIST.md)

## Cấu trúc thư mục
```text
roomhub-platform/
├── apps/
│   ├── storefront/   (submodule) Next.js + Tailwind + shadcn: tìm phòng, 360° viewer, đặt lịch/cọc
│   ├── admin-web/    (submodule) Next.js + Ant Design: Admin & Dashboard Chủ nhà
│   ├── api/          (submodule) NestJS microservices + Prisma
│   └── mobile/       (submodule) Giai đoạn sau
├── docs/
│   ├── ARCHITECTURE.md
│   ├── SETUP-GUIDE.md
│   ├── erd/ERD.md
│   └── specs/PHASE-0-CHECKLIST.md
├── infrastructure/
│   └── docker/
│       ├── docker-compose.yml
│       └── init-db/01-init-schemas.sql
├── .env.example
├── .gitignore
├── .gitmodules.example
└── pnpm-workspace.yaml
```

## Chạy hạ tầng local
```powershell
Copy-Item .env.example .env
docker compose -f infrastructure/docker/docker-compose.yml up -d
```
