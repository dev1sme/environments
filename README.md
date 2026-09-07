# Repo này mong muốn là gì ?

Repo này dựng tools cần thiết để demo và dev local cho các ứng dụng.
Ứng dụng sau khi build bằng docker sẽ được cập nhật conf ở đây để có thể demo HTTPS trong mạng LAN nội bộ.

Domain nội bộ: `*.thomson.cba`. Cert ở `tools/ssl-cert/` **không phải self-signed** — do `CYBRIDGE ASIA Root CA` cấp (mkcert), root CA đó nằm ở `/usr/local/share/ca-certificates/mkcert-rootCA-CBA.cer`, hết hạn 2045. Máy nào đã cài root CA đó thì vào HTTPS không cảnh báo gì.

## Kiến trúc

```
docker-compose.yml        CHỈ include, không khai service nào; giữ network env-net
makefile                  shortcut cho mọi thao tác — `make help`

tools/proxy/              nginx reverse proxy + TLS. conf.d/ vhost mỗi app 1 file,
                          00-defaults.conf config dùng chung, snippets/ include vào location
tools/postgres/           postgres dùng chung, mỗi app 1 database. init/ chạy khi volume trống
tools/coredns/            DNS nội bộ cho *.thomson.cba (DƯ trong LAN công ty — xem file đó)
tools/codegraph/          code intelligence cho AI agent qua MCP
tools/ssl-cert/           wildcard cert cho *.thomson.cba (do CYBRIDGE ASIA Root CA cấp)
tools/java/              hướng dẫn Dev Containers cho project Java (docs, không phải tool)

assets/                   static assets dùng chung (dev.js — badge overlay "DEV ENV")
projects/                 mỗi app 1 thư mục, docker-compose riêng
```

**Mỗi tool giữ `docker-compose.yml` riêng trong thư mục của nó**, root chỉ `include`:

```yaml
include:
  - path: tools/proxy/docker-compose.yml
    env_file: .env
  - path: tools/postgres/docker-compose.yml
    env_file: .env
  # ...
```

Vẫn cùng 1 compose project nên `docker compose ps` thấy hết và gọi được bằng tên service (`docker compose up -d proxy`). Config của tool nào nằm cạnh file của tool đó.

Thêm tool mới: tạo `tools/<ten>/docker-compose.yml` + thêm 1 entry vào `include`. Hai chỗ dễ sai:

1. **Đừng khai `external: true`** cho `env-net` trong file được include — hai khai báo bị merge, network gộp thành external, máy mới `make up` báo `network env-net declared as external, but could not be found`. Khai `name: env-net` như root.
2. **Đường dẫn tương đối resolve theo thư mục của file đó**, không phải root. Trong `tools/proxy/` viết `./conf.d`, không phải `./tools/proxy/conf.d`.

## Setup lần đầu

1. Copy `.env.example` → `.env`, đổi `POSTGRES_PASSWORD` và set `HOST_IP` = IP LAN của máy host:
   ```bash
   ip -4 addr show | grep -oP 'inet \K[\d.]+' | grep -v '^127\.'
   ```
2. Sinh zone file cho DNS: `make dns-init`
3. `make up`
4. Trên máy client trong LAN: trỏ DNS về `HOST_IP`. Cách tốt nhất là set ở DHCP của router — mọi máy trong LAN tự nhận, không phải cấu hình gì thêm. Không sửa được router thì set DNS thủ công trên từng máy (vẫn hơn sửa `hosts` file, vì wildcard hoạt động — thêm app mới không phải sửa lại client).
5. Verify: `make dns-test`

## Thêm app mới

1. Tạo `projects/<app>/docker-compose.yml`, tham khảo `projects/_example/`. Join network `env-net` (external), không publish port ra host — route qua proxy.
2. Copy `tools/proxy/conf.d/_example.conf.dist` → `tools/proxy/conf.d/<app>.conf`, sửa `server_name` và giá trị `$upstream`.
3. Cần DB riêng: thêm `CREATE DATABASE <app>;` vào `tools/postgres/init/01-init.sql`. Script init chỉ chạy khi volume `.data/postgres` còn trống — app đã chạy trước đó thì `make db p=<app>`.
4. `make app-up p=<app>` rồi `make reload`.

Không cần thêm DNS record — zone đã có wildcard `*`.

## Lệnh hay dùng

```bash
make help                # danh sách đầy đủ
make up / down / rs
make ls                  # container nào đang chạy
make test                # nginx -t, check config
make reload              # reload nginx, không đứt kết nối đang mở
make logs n=proxy
make app-up p=myapp
make db p=myapp
make cert                # xem cert hết hạn khi nào, SAN gồm domain nào
```

`make reload` thay vì `restart proxy`: worker cũ phục vụ xong request đang dở mới thoát, demo đang chạy không bị đứt.
Luôn `make test` trước `make reload` — `nginx -s reload` với config sai thì nginx **giữ config cũ và vẫn chạy**, không báo lỗi rõ ràng, sửa xong tưởng đã apply mà thực ra chưa.

## Badge "DEV ENV"

`assets/dev.js` được proxy tự inject vào mọi response HTML, **app không cần sửa source**. Cơ chế ở `tools/proxy/conf.d/00-defaults.conf`:

```nginx
map $host $dev_script { ~^api ''; ~^assets ''; default '<script src="/__dev/dev.js"></script>'; }
sub_filter '</body>' '$dev_script</body>';
```

Domain khớp `api*` không bị inject (response là JSON).

Đường dẫn là **cùng origin** (`/__dev/dev.js`), do `snippets/dev-badge.conf` serve — nhớ `include` snippet đó trong mỗi `server` block. Không dùng `//assets.thomson.cba/dev.js`: xem mục dưới, đó là bug đã sửa.

Muốn inject được thì `snippets/proxy-params.conf` phải bỏ `Accept-Encoding` — `sub_filter` không rewrite được response đã gzip. Đánh đổi bandwidth lấy tiện lợi, hợp lý cho môi trường dev.
App không có `</body>` (SPA render toàn bộ bằng JS, hoặc trang meta-refresh như `/icms/`) thì không inject được — trường hợp đó nhúng tay:

```html
<script src="/__dev/dev.js"></script>
```

## Cho điện thoại / máy khách xem demo

Thiết bị chưa cài `CYBRIDGE ASIA Root CA` sẽ hiện cảnh báo cert. Bấm "vẫn tiếp tục" là xem được trang, nhưng exception đó **chỉ áp cho đúng 1 host**.

Muốn hết cảnh báo: copy `/usr/local/share/ca-certificates/mkcert-rootCA-CBA.cer` sang thiết bị rồi cài.

- **iOS** — mở file bằng Safari → Settings → *Profile Downloaded* → Install. Rồi **bắt buộc** vào Settings → General → About → Certificate Trust Settings → bật full trust cho CA đó. Thiếu bước bật full trust là cài rồi vẫn cảnh báo.
- **Android** — Settings → Security → Encryption & credentials → Install a certificate → **CA certificate** (không phải "VPN & app user certificate").

## Mấy chỗ dễ sập

**Upstream phải nằm trong biến.** Viết `proxy_pass http://app:3000;` trực tiếp thì nginx resolve tên lúc parse config — app container chưa chạy là **cả proxy chết**, kéo theo mọi app khác:

```
nginx: [emerg] host not found in upstream "app"
```

Cho vào biến (`set $upstream http://app:3000;` rồi `proxy_pass $upstream;`) thì nginx resolve lúc có request, nhờ `resolver 127.0.0.11` khai ở `00-defaults.conf`. App tắt thì domain đó trả 502, phần còn lại vẫn sống. Template `_example.conf.dist` đã làm sẵn — đừng sửa lại thành literal.

**Đừng nhúng asset từ host khác.** Cert lỗi ở subresource (script/css/img) thì browser **chặn im lặng, không hỏi gì** — khác với trang chính, trang chính thì nó hiện interstitial cho bấm "tiếp tục".

Biểu hiện đã gặp thật: badge hiện trên máy dev (có root CA), không hiện trên điện thoại (không có root CA). Trang vẫn mở bình thường vì đã bấm tiếp tục cho `icms.thomson.cba`, nhưng `assets.thomson.cba` là host khác nên script bị chặn — không log, không lỗi, chỉ là không có badge. Mất thời gian mới lần ra.

Nên mọi thứ inject vào trang phải đi **cùng origin** với trang. Đó là lý do có `snippets/dev-badge.conf` thay vì trỏ thẳng sang `assets.thomson.cba`.

**Wildcard cert chỉ phủ 1 tầng.** `*.thomson.cba` khớp `myapp.thomson.cba` nhưng **không** khớp `api.myapp.thomson.cba`. DNS thì resolve được (zone có wildcard), nên biểu hiện là truy cập được mà browser chặn TLS. Đặt tên domain 1 tầng: `myapp-api.thomson.cba`, không phải `api.myapp.thomson.cba`.

**coredns bind riêng vào `HOST_IP`, không bind `0.0.0.0`.** Host chạy systemd-resolved giữ `127.0.0.53:53`, bind all là `address already in use`. Đổi IP máy thì sửa `.env` rồi `make dns-init && make rs`.

## Quan hệ với docker-starfish

`docker-starfish/` là môi trường dev PHP dùng chung runtime — nginx ở đó vừa serve file vừa gọi php-fpm (`root` + `fastcgi_pass`), nên phải mount source vào container proxy và build image nginx riêng.

Repo này mỗi app là 1 container tự chạy HTTP server, nginx chỉ reverse proxy — không `root`, không `fastcgi`, dùng thẳng `image: nginx:alpine` với config bind-mount (sửa conf xong `make reload`, không phải rebuild).

Bê từ starfish sang: `resolver` cho upstream biến, `client_max_body_size` + timeout, header WebSocket, auto-inject dev.js bằng `sub_filter`, `tools/coredns/`, `makefile`, pattern gitignore `.example`.
