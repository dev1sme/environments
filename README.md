# Repo này mong muốn là gì ?

Repo này dựng tools cần thiết để demo và dev local cho các ứng dụng.
Ứng dụng sau khi build bằng docker sẽ được cập nhật conf ở đây để có thể demo HTTPS trong mạng LAN nội bộ.

Domain nội bộ: `*.thomson.cba` (khai ở `DOMAIN` trong `.env`).

## Kiến trúc

```
docker-compose.yml   CHỈ include, không khai service nào; giữ network env-net
makefile             shortcut cho mọi thao tác — `make help`
.env                 DOMAIN, HOST_IP, POSTGRES_*, PROJECTS_ROOT, HOST_UID/GID
assets/              static assets dùng chung (dev.js — badge overlay "DEV ENV")
projects/            mỗi app 1 thư mục, docker-compose riêng
tools/<ten>/         mỗi tool 1 thư mục: docker-compose.yml + config + README riêng
```

| Tool | Làm gì | Chi tiết |
|---|---|---|
| `tools/proxy/` | nginx reverse proxy + TLS cho `*.$DOMAIN` | [README](tools/proxy/README.md) |
| `tools/ssl-cert/` | wildcard cert, cách cài CA lên điện thoại | [README](tools/ssl-cert/README.md) |
| `tools/postgres/` | postgres dùng chung, mỗi app 1 database | [README](tools/postgres/README.md) |
| `tools/coredns/` | DNS nội bộ (DƯ trong LAN công ty) | [README](tools/coredns/README.md) |
| `tools/codegraph/` | code intelligence cho AI agent qua MCP | [README](tools/codegraph/README.md) |
| `tools/java/` | hướng dẫn Dev Containers cho project Java (docs) | [README](tools/java/README.md) |

**Mỗi tool giữ `docker-compose.yml` riêng**, root chỉ `include`:

```yaml
include:
  - path: tools/proxy/docker-compose.yml
    env_file: .env
  # ...
```

Vẫn cùng 1 compose project nên `docker compose ps` thấy hết và gọi được bằng tên service (`docker compose up -d proxy`). Config của tool nào nằm cạnh file của tool đó.

Thêm tool mới: tạo `tools/<ten>/docker-compose.yml` + thêm 1 entry vào `include`. Hai chỗ dễ sai:

1. **Đừng khai `external: true`** cho `env-net` trong file được include — hai khai báo bị merge, network gộp thành external, máy mới `make up` báo `network env-net declared as external, but could not be found`. Khai `name: env-net` như root.
2. **Đường dẫn tương đối resolve theo thư mục của file đó**, không phải root. Trong `tools/proxy/` viết `./conf.d`, không phải `./tools/proxy/conf.d`.

## Setup lần đầu

1. Copy `.env.example` → `.env`, đổi `POSTGRES_PASSWORD`, set `HOST_IP` = IP LAN của máy host:
   ```bash
   ip -4 addr show | grep -oP 'inet \K[\d.]+' | grep -v '^127\.'
   ```
2. `make up`
3. Client trong LAN cần resolve `*.$DOMAIN` về `HOST_IP`. LAN công ty đã có sẵn — xem [tools/coredns/README.md](tools/coredns/README.md) nếu ở mạng khác.
4. Máy/điện thoại xem demo cần trust root CA — xem [tools/ssl-cert/README.md](tools/ssl-cert/README.md).

## Thêm app mới

1. Tạo `projects/<app>/docker-compose.yml`, tham khảo `projects/_example/`. Join network `env-net` (external), không publish port ra host — route qua proxy.
2. Copy `tools/proxy/conf.d/_example.conf.dist` → `tools/proxy/conf.d/<app>.conf`, sửa `server_name` và giá trị `$upstream`. Đọc [tools/proxy/README.md](tools/proxy/README.md) trước — có mấy chỗ sập được.
3. Cần DB riêng: xem [tools/postgres/README.md](tools/postgres/README.md).
4. `make app-up p=<app>` rồi `make reload`.

Không cần thêm DNS record — zone đã có wildcard `*`.

## Lệnh hay dùng

```bash
make help                # danh sach day du
make up / down / rs
make ls                  # container nao dang chay
make test                # nginx -t, check config
make reload              # reload nginx, khong dut ket noi dang mo
make logs n=proxy
make app-up p=myapp
make db p=myapp
make cert                # xem cert het han khi nao, SAN gom domain nao
```

## Đem repo sang môi trường khác

Hai thứ gắn với công ty hiện tại: **domain** (`.cba`) và **cert** (do `CYBRIDGE ASIA Root CA` cấp, cả LAN đã trust). Sang chỗ khác thì cả hai vô giá trị.

```bash
make domain-set d=mycompany.local    # doi domain noi bo
make dns-init                        # sinh lai zone
make cert-init                       # sinh CA rieng + wildcard cert
make test && make reload
```

`domain-set` chỉ sed những chỗ **không** derive được. Corefile (`{$DOMAIN}`), zone template (`__DOMAIN__`), makefile (`$(DOMAIN)`) đã derive từ `.env` nên không nằm trong diện sed. Còn `server_name` của nginx thì bắt buộc sed vì nginx không đọc biến môi trường trong config.

Target bắt buộc **working tree sạch** — nó sed toàn repo nên phải có commit để `git checkout .` là về được. Chạy xong `git diff` đọc lại trước khi commit.

Chi tiết `cert-init`: [tools/ssl-cert/README.md](tools/ssl-cert/README.md).

## Quan hệ với docker-starfish

`docker-starfish/` là môi trường dev PHP dùng chung runtime — nginx ở đó vừa serve file vừa gọi php-fpm (`root` + `fastcgi_pass`), nên phải mount source vào container proxy và build image nginx riêng.

Repo này mỗi app là 1 container tự chạy HTTP server, nginx chỉ reverse proxy. Chi tiết cái gì bê từ starfish sang và làm khác chỗ nào: [tools/proxy/README.md](tools/proxy/README.md).

`docker-starfish/` có `.git` riêng nên bị gitignore — nó là repo tham khảo, không phải phần của repo này.
