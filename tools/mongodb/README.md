# mongodb — instance dùng chung

Một instance, mỗi app 1 database riêng. **Không bật auth** — chỉ publish `127.0.0.1`, container khác vào qua `env-net`. Database tự tạo khi app ghi lần đầu, không cần provision.

```
../../.data/mongodb   data thật, GITIGNORE
```

Kết nối:

- **Từ host / Compass** — `mongodb://127.0.0.1:27017/<db>`
- **Từ container khác** — join `env-net` rồi dùng hostname `mongodb:27017`

```yaml
environment:
  MONGODB_URI: mongodb://mongodb:27017/myapp
```

## Vì sao có `GLIBC_TUNABLES`

MongoDB 8.x + Linux kernel 6.19/7.0 crash lúc khởi động (SERVER-121912): TCMalloc và glibc tranh RSEQ. `glibc.pthread.rseq=1` bắt glibc giữ RSEQ trước, TCMalloc tự tắt phần dùng RSEQ.

Bỏ khi MongoDB release fix (theo dõi SERVER-125742).

## Backup / chuyển data

```bash
make mongo-dump                 # mongodump --archive --gzip ra .data/dump/mongo_<ngay>.archive.gz
make mongo-restore f=<file>     # mongorestore, KHÔNG --drop: trùng _id thì bỏ qua document đó
```

## Version

Pin cùng bản với app đang dùng (`mongo:8.0.23`). Nâng major thì phải theo `featureCompatibilityVersion` từng bước — không nhảy thẳng 8 → 9 trên cùng `.data/mongodb`.
