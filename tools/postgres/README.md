# postgres — instance dùng chung

Một instance, mỗi app 1 database riêng. Database + role **tạo bằng tay** (DBeaver hoặc `make psql`), không auto-provision.

```
../../.data/postgres   data thật, GITIGNORE
init/                  chỉ chạy khi .data/postgres còn TRỐNG — hiện để trống
```

Kết nối:

- **Từ host / DBeaver** — `127.0.0.1:5432`, user/pass trong `.env` gốc repo
- **Từ container khác** — join `env-net` rồi dùng hostname `postgres:5432`, không đi qua port publish

```yaml
environment:
  DATABASE_URL: postgresql://dev:<pass>@postgres:5432/myapp
```

## Tạo database cho app mới

```sql
CREATE ROLE myapp LOGIN PASSWORD '...';
CREATE DATABASE myappdb OWNER myapp;
```

Chạy trong DBeaver là xong. Không sửa file nào, không restart gì.

## Auth: vì sao `pg_hba` là `md5`

`POSTGRES_INITDB_ARGS: "--auth-host=md5"` trong compose sinh ra luật:

```
host all all all md5
```

**`md5` ở đây là luật RỘNG, không phải luật yếu.** Đã test:

- role lưu hash md5 → server hỏi md5
- role lưu hash SCRAM → server **tự chuyển sang SCRAM**

Ngược lại `scram-sha-256` mới là luật **chặt** — từ chối thẳng role nào lưu md5.

Cần nó vì driver JDBC của icms (postgresql 9.1, 2011) ra đời trước SCRAM, không nói được giao thức đó.

**Chỉ set được lúc initdb**, khi `.data/postgres` còn trống. Volume đã init rồi thì phải sửa tay `.data/postgres/pg_hba.conf` — file đó gitignore, không history, xoá `.data/` là mất.

## Auth: default hash vẫn là SCRAM

`--auth-host=md5` khiến initdb ghi luôn `password_encryption = md5` vào `postgresql.conf` — mọi role tạo sau đó cũng hash md5. Không muốn vậy, nên compose override:

```yaml
command: ["postgres", "-c", "password_encryption=scram-sha-256"]
```

Dùng `-c` chứ không sửa `postgresql.conf`, vì file đó nằm trong `.data/`.

Nên: **role mới mặc định SCRAM**, chỉ role nào cần md5 mới khai rõ:

```sql
SET password_encryption = 'md5';
CREATE ROLE icms LOGIN PASSWORD 'icms';
RESET password_encryption;
```

Kiểm tra role nào đang dùng hash gì:

```sql
SELECT rolname, left(rolpassword, 14) FROM pg_authid;
```

## Vì sao image là `postgres:16`, không phải `16-alpine`

Cần locale `C.UTF-8` có trong OS để tạo database khớp collation của dump icms:

```sql
CREATE DATABASE icmsdb OWNER icms
  ENCODING 'UTF8' LC_COLLATE 'C.UTF-8' LC_CTYPE 'C.UTF-8' TEMPLATE template0;
```

Đã verify chạy được trên debian image. alpine dùng musl, chưa test.

## Backup

Không có `init/` để dựng lại, nên backup là đường duy nhất:

```bash
make db-dump                  # pg_dumpall ra .data/dump/<ngay>.sql
make db-restore f=<file>
```

Init script chỉ dựng lại cấu trúc rỗng — backup cứu được cả data.

## Xoá sạch làm lại

```bash
docker compose rm -sf postgres
trash .data/postgres
make up
```

**Mất data của MỌI app** trong instance, không chỉ 1 app — kể cả `icmsdb` (1.5GB). Và lần init lại này là cơ hội duy nhất để `--auth-host=md5` áp dụng.
