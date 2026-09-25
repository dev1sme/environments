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

Cần nó cho app nào dùng driver DB cũ hơn PostgreSQL 10 — SCRAM ra sau, driver đời trước không nói được giao thức đó.

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
CREATE ROLE legacyapp LOGIN PASSWORD '...';
RESET password_encryption;
```

Kiểm tra role nào đang dùng hash gì:

```sql
SELECT rolname, left(rolpassword, 14) FROM pg_authid;
```

## Vì sao image là `postgres:16`, không phải `16-alpine`

App nào cần collation cụ thể thì khai lúc tạo database — nhưng locale đó phải có trong OS của image:

```sql
CREATE DATABASE appdb OWNER appuser
  ENCODING 'UTF8' LC_COLLATE 'C.UTF-8' LC_CTYPE 'C.UTF-8' TEMPLATE template0;
```

Đã verify chạy được trên debian image. alpine dùng musl, chưa test.

## Backup

Không có `init/` để dựng lại, nên backup là đường duy nhất:

```bash
make db-dump                  # pg_dumpall + gzip ra .data/dump/all_<ngay>.sql.gz
make db-restore f=<file>
```

- Dùng `pg_dumpall` chứ không `pg_dump` vì cần cả **role** — restore mà thiếu role thì mất luôn hash md5 của role legacy (xem phần Auth).
- Luôn gzip: dump plain SQL của DB 1.5GB là rất lớn.
- **Chỉ restore vào cluster mới init.** Dump có sẵn `CREATE ROLE` / `CREATE DATABASE`, cluster đã có các object đó sẽ báo lỗi trùng. Cách làm: xoá sạch (mục dưới), `make up`, rồi `make db-restore`.

Init script chỉ dựng lại cấu trúc rỗng — backup cứu được cả data.

## Xoá sạch làm lại

```bash
docker compose rm -sf postgres
trash .data/postgres
make up
```

**Mất data của MỌI app** trong instance, không chỉ 1 app. Bù lại, lần init lại này là cơ hội duy nhất để đổi `POSTGRES_INITDB_ARGS`.
