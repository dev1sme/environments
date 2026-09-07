# proxy — nginx reverse proxy + TLS termination

Mỗi app 1 container tự chạy HTTP server, nginx chỉ chuyển tiếp. Không `root`, không `fastcgi`, nên dùng thẳng `image: nginx:alpine` với config bind-mount — sửa conf xong `make reload`, không phải rebuild image.

```
conf.d/00-defaults.conf      config dùng chung (tầng http): resolver, timeout, body size, inject dev.js
conf.d/vhosts/<app>.conf       vhost của app — GITIGNORE, cấu hình local
conf.d/_example.conf.dist    template cho app mới
conf.d/*.conf.dist           vhost của tool đang tắt (đổi thành .conf để bật)
snippets/proxy-params.conf   header proxy + WebSocket, include vào từng location
snippets/dev-badge.conf      route /__dev/dev.js cùng origin, include vào từng server
auth/                        file htpasswd, gitignore
```

`00-defaults.conf` có prefix `00-` vì nginx include theo thứ tự alphabet — nó phải load trước.

Mọi directive trong `conf.d/*.conf` nằm ở context `http` (nginx.conf gốc include vào trong `http`), nên `resolver`, `map`, `sub_filter` đều khai được ở đây — **không cần build image riêng** để thay `nginx.conf` như `docker-starfish` làm.

## Thêm app mới

```bash
cp conf.d/_example.conf.dist conf.d/vhosts/<app>.conf
# sua server_name + gia tri $upstream
make reload
```

`conf.d/vhosts/` bị gitignore: vhost của app cụ thể là cấu hình local, không thuộc repo môi trường. nginx gốc chỉ include `conf.d/*.conf` nên `00-defaults.conf` include tay tầng con:

```nginx
include /etc/nginx/conf.d/vhosts/*.conf;
```

`make reload` thay vì `restart`: worker cũ phục vụ xong request đang dở mới thoát, demo đang chạy không bị đứt.

Luôn `make test` trước `make reload` — `nginx -s reload` với config sai thì nginx **giữ config cũ và vẫn chạy**, không báo lỗi rõ ràng, sửa xong tưởng đã apply mà thực ra chưa. `make reload` đã gọi `test` trước.

## Badge "DEV ENV"

`assets/dev.js` được inject vào mọi response HTML, **app không cần sửa source**:

```nginx
map $host $dev_script { ~^api ''; ~^assets ''; default '<script src="/__dev/dev.js"></script>'; }
sub_filter '</body>' '$dev_script</body>';
```

Domain khớp `api*` không bị inject (response là JSON). `sub_filter_types` mặc định chỉ `text/html` nên JSON và static file không bị chạm.

Đường dẫn **cùng origin** (`/__dev/dev.js`), do `snippets/dev-badge.conf` serve — nhớ `include` snippet đó trong mỗi `server` block. Vì sao không trỏ sang host assets: xem mục "Đừng nhúng asset từ host khác" dưới.

Muốn inject được thì `snippets/proxy-params.conf` phải bỏ `Accept-Encoding` — `sub_filter` không rewrite được response đã gzip. Đánh đổi bandwidth lấy tiện lợi, hợp lý cho môi trường dev.

App không có `</body>` (SPA render toàn bộ bằng JS, hoặc trang meta-refresh) thì không inject được — trường hợp đó nhúng tay `<script src="/__dev/dev.js"></script>`.

## Mấy chỗ dễ sập

### Upstream phải nằm trong biến

Viết trực tiếp thì nginx resolve tên lúc **parse config** — app container chưa chạy là **cả proxy chết**, kéo theo mọi app khác:

```
nginx: [emerg] host not found in upstream "app"
```

Cho vào biến thì nginx resolve lúc có request, nhờ `resolver 127.0.0.11` khai ở `00-defaults.conf`:

```nginx
set $upstream http://app:3000;
include /etc/nginx/snippets/proxy-params.conf;
proxy_pass $upstream;
```

App tắt thì domain đó trả 502, phần còn lại vẫn sống. `_example.conf.dist` đã làm sẵn — đừng sửa lại thành literal.

**Ngoại lệ — app chạy `network_mode: host`.** Container đó không có tên trong Docker DNS, phải đi qua `host.docker.internal` (map bằng `extra_hosts` trong `docker-compose.yml` của thư mục này), và ở đó **phải dùng literal**: nginx `resolver` chỉ query DNS, **không đọc `/etc/hosts`** — dạng biến sẽ báo `host.docker.internal could not be resolved`. Literal an toàn vì entry `/etc/hosts` luôn tồn tại, khác tên container (biến mất khỏi Docker DNS khi container tắt).

App nào sửa được địa chỉ DB/upstream (config file, biến môi trường, hoặc mount đè file properties trong image) thì cho join `env-net` rồi dùng upstream dạng biến — gọn hơn và proxy không phụ thuộc app. `extra_hosts` để lại cho trường hợp không sửa được.

### Đừng nhúng asset từ host khác

Cert lỗi ở subresource (script/css/img) thì browser **chặn im lặng, không hỏi gì** — khác trang chính, trang chính thì hiện interstitial cho bấm "tiếp tục".

Biểu hiện đã gặp thật: badge hiện trên máy dev (có root CA), không hiện trên điện thoại (không có root CA). Trang vẫn mở vì đã bấm tiếp tục cho domain của app, nhưng `assets.thomson.cba` là host khác nên script bị chặn — không log, không lỗi, chỉ là không có badge.

Nên mọi thứ inject vào trang phải đi **cùng origin**. Đó là lý do có `snippets/dev-badge.conf`.

### Wildcard cert chỉ phủ 1 tầng

`*.thomson.cba` khớp `myapp.thomson.cba` nhưng **không** khớp `api.myapp.thomson.cba`. DNS resolve được (zone có wildcard) nên biểu hiện là truy cập được mà browser chặn TLS.

Đặt tên domain 1 tầng: `myapp-api.thomson.cba`, không phải `api.myapp.thomson.cba`.

### App legacy sau TLS termination

Tomcat/PHP không biết request gốc là HTTPS nên `sendRedirect()` trả `Location: http://...` — client bị đẩy sang port 80 rồi mới 301 về 443, thêm 1 vòng và **mất POST body**. Sửa tại proxy:

```nginx
proxy_redirect http://$host/ https://$host/;
proxy_cookie_flags ~ secure;
```

## Bê từ docker-starfish

`resolver` cho upstream biến, `client_max_body_size` + timeout (default nginx là `1m`, upload ảnh là ăn `413`), header WebSocket, auto-inject dev.js bằng `sub_filter`.

Làm khác starfish 2 chỗ:

1. **WebSocket header** — starfish hardcode `Connection "upgrade"` ở mọi block, sai với request HTTP thường. Ở đây map theo `$http_upgrade`: có upgrade thì `upgrade`, không thì `close`.
2. **Không build image nginx riêng** — starfish phải build vì nó thay cả `nginx.conf`. Ở đây nhét vào `00-defaults.conf` là đủ (cùng context `http`), giữ được `image: nginx:alpine` và `make reload`.

Kèm 1 bug của starfish: `sub_filter` của nó thiếu `Accept-Encoding ""` nên app nào bật gzip là inject im lặng không tác dụng.
