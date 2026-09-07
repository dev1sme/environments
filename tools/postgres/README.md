# postgres — instance dùng chung

Một instance, mỗi app 1 database riêng trong đó. Đỡ phải dựng postgres riêng cho từng app.

```
init/01-init.sql    CREATE DATABASE cho từng app
../../.data/postgres  data thật, GITIGNORE
```

User/password lấy từ `POSTGRES_USER` / `POSTGRES_PASSWORD` trong `.env` gốc repo.

## Không publish port ra host

App join network `env-net` rồi kết nối bằng hostname `postgres`:

```yaml
environment:
  DATABASE_URL: postgresql://dev:<pass>@postgres:5432/myapp
```

Cần psql từ host thì `make psql`. Không mở port ra ngoài để tránh đụng postgres của project khác — trên máy này `icms-pg` đã chiếm `5432`.

## Tạo database cho app mới

**Chưa từng chạy postgres** (`.data/postgres` còn trống) — thêm dòng vào `init/01-init.sql`:

```sql
CREATE DATABASE myapp;
```

**Đã chạy rồi** — script trong `init/` **không chạy lại nữa**. Đây là hành vi của image postgres: entrypoint chỉ chạy `docker-entrypoint-initdb.d/` khi data directory còn trống. Dùng:

```bash
make db p=myapp
```

Vẫn nên thêm dòng `CREATE DATABASE` vào `01-init.sql` để máy mới setup từ đầu là có đủ.

## Xoá sạch làm lại

```bash
docker compose rm -sf postgres
trash .data/postgres          # hoac rm -rf neu khong co trash
docker compose up -d postgres
```

Lần này `init/` sẽ chạy lại. **Mất toàn bộ data của mọi app** trong instance, không chỉ 1 app.
