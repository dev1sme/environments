# homepage — dashboard https://home.$DOMAIN

[Homepage](https://gethomepage.dev) liệt kê mọi domain của proxy, chấm xanh/đỏ theo upstream sống/chết. Không phải khai tay: danh sách **sinh từ `tools/proxy/conf.d`** bởi `gen-services.sh` mỗi lần `make reload` (và `make up`).

```
config/services.yaml    SINH TỰ ĐỘNG bởi `make home-gen` — gitignore, sửa tay là mất
config/bookmarks.yaml   link viết tay (pgAdmin, docs, ...) — commit
config/settings.yaml    title, theme, layout nhóm — commit
config/widgets.yaml     widget đầu trang — commit
config/custom.css       nền gradient, hiệu ứng hover — commit
config/*                còn lại homepage tự tạo (skeleton, logs/) — gitignore
```

Thêm app mới: làm như cũ — thêm `.conf` vào `tools/proxy/conf.d/vhosts/`, `make reload`, F5 dashboard. Homepage đọc lại `services.yaml` mỗi request, không cần restart.

- **Apps** = `conf.d/vhosts/*.conf`, **Tools** = `conf.d/*.conf`. Tên hiển thị = phần trước dấu `.` đầu tiên của `server_name`.
- Trạng thái dùng `ping` tên upstream qua `env-net` — xanh = container còn sống. Không dùng `siteMonitor` vì HTTP status của upstream không nói app sống hay chết (icms `/` trả 404 vì app nằm ở `/icms/`).
- Vhost static (`root`) không có chấm trạng thái.
- Icon đoán theo tên domain/upstream trong hàm `icon()` của `gen-services.sh` (tomcat, api, static, ...), không khớp thì `mdi-web`. Tên icon: [dashboard-icons](https://dashboardicons.com) (`*.png`) hoặc [MDI](https://pictogrammers.com/library/mdi/) (`mdi-*`) — trình duyệt tải từ CDN, máy không có internet thì mất icon, không mất link.

Mấy chỗ dễ sai:

1. **Image `latest` không tự cập nhật** — `make up` dùng image đã pull. Lên bản mới:
   ```bash
   make reup n=homepage
   ```
   Homepage hay đổi format config giữa các bản — lên xong mà dashboard trống/lỗi thì xem `make logs n=homepage` và [release notes](https://github.com/gethomepage/homepage/releases). Bản đã test: `v2.4.0`.
2. **`HOMEPAGE_ALLOWED_HOSTS`** phải khớp domain truy cập, không thì 400 `Host validation failed`. Đang set `home.${DOMAIN}` nên `make domain-set` tự đúng.
3. **`config/` mount rw** — homepage tự copy skeleton còn thiếu và ghi `logs/`. Chạy bằng `PUID/PGID` = `HOST_UID/GID` nên file thuộc user host, không phải root.
4. **Không mount `docker.sock`** — socket = root trên host, đổi lấy auto-discovery không đáng.
