# docs — tài liệu markdown cho cả LAN

`https://docs.$DOMAIN` render file `.md` trong **`docs/` ở gốc repo** bằng [Docsify](https://docsify.js.org). **Không có auth** — mọi máy trong LAN đọc được, đừng bỏ vào đây file chứa mật khẩu/IP nội bộ.

```
docs/                      file .md của ba — GITIGNORE, nội dung cá nhân
tools/docs/index.html      trang docsify (commit)
tools/proxy/conf.d/docs.conf  vhost
```

Thêm tài liệu: bỏ file `.md` vào `docs/` (thư mục con thành nhóm trong sidebar), F5 là thấy — không `make reload`, không viết `_sidebar.md`.

- Tiêu đề sidebar = tên file bỏ `.md`, `-`/`_` thành dấu cách. Muốn tiếng Việt có dấu thì đặt tên file có dấu.
- Có `docs/README.md` thì nó là trang chủ; không có thì trang chủ tự liệt kê mọi file.
- File/thư mục bắt đầu bằng `_` bị bỏ qua.
- Mỗi trang có nút **Tải file .md**. Link thẳng tới file gốc cũng mở được: `https://docs.$DOMAIN/<duong-dan>.md`.
- Tài liệu nằm chỗ khác: symlink vào `docs/`, hoặc đổi dòng mount `../../docs` trong `tools/proxy/docker-compose.yml` rồi `make up`.

Cách chạy:

1. **Sidebar tự sinh** — `/__list/` là nginx `autoindex_format json`. `index.html` duyệt đệ quy, dựng markdown sidebar rồi chặn XHR `_sidebar.md` / `README.md` của docsify, trả về bản sinh ra.
2. **Thứ tự nạp script có nghĩa** — plugin (search, copy-code) phải nạp trước `docsify.min.js`, không thì không kịp đăng ký. Ngôn ngữ prism nạp sau (cần Prism của docsify).
3. **Script tải từ CDN** (`docsify@4`, ghim major) — máy xem cần internet.
4. **`.md` trả `text/markdown`** — `mime.types` của nginx không có `.md`, mặc định là octet-stream (trình duyệt ép tải về).
