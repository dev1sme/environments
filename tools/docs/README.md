# docs — tài liệu markdown cho cả LAN

`https://docs.$DOMAIN` render file `.md` trong **`docs/` ở gốc repo** bằng [MkDocs Material](https://squidfunk.github.io/mkdocs-material/). **Không có auth** — mọi máy trong LAN đọc được, đừng bỏ vào đây file chứa mật khẩu/token.

```
docs/                              file .md của ba — GITIGNORE, nội dung cá nhân
tools/docs/mkdocs.yml              tên site, theme, extension markdown
tools/docs/overrides/partials/     ghi đè template Material (nút tải .md)
tools/proxy/conf.d/docs.conf       vhost: / -> mkdocs, /raw/ -> file gốc
```

Thêm tài liệu: bỏ file `.md` vào `docs/`, F5 — mkdocs watch thư mục, tự build lại.

- `docs/README.md` (hoặc `index.md`) là trang chủ. **Không có thì `/` trả 404.**
- Menu tự sinh theo thư mục. Tiêu đề = dòng `# ...` đầu file, không có thì lấy tên file.
- Nút tải (góc phải mỗi trang) trỏ `/raw/<file>.md` — nginx serve thẳng file gốc, không qua mkdocs.
- Tài liệu nằm chỗ khác: symlink vào `docs/`, hoặc đổi mount `../../docs` trong `docker-compose.yml` của tool này **và** của proxy (cho `/raw/`), rồi `make up`.
- Cập nhật: `make reup n=docs`.

Mấy chỗ dễ sai:

1. **`/content` mount riêng, không lồng trong `/docs`.** `/docs` mount `:ro` nên docker không tạo được mountpoint con — container không start (`mkdirat ... read-only file system`).
2. **MkDocs 2.0** — log của image đang cảnh báo bản 2.0 bỏ plugin và viết lại hệ thống theme, `overrides/` sẽ hỏng. Image dùng `latest`; nếu sau `make reup n=docs` mà trang lỗi, xem `make logs n=docs` và [bài phân tích của Material](https://squidfunk.github.io/mkdocs-material/blog/2026/02/18/mkdocs-2.0/). Bản đã test: mkdocs-material 9.7.7 / mkdocs 1.6.1.
3. **`serve` là dev server** — đủ cho LAN, không đưa ra internet.
