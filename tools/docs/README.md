# docs — tài liệu markdown cho cả LAN

`https://docs.$DOMAIN` render file `.md` trong **`docs/` ở gốc repo** bằng [Zensical](https://zensical.org) — bản kế nhiệm Material for MkDocs, đọc thẳng `mkdocs.yml`. **Không có auth** — mọi máy trong LAN đọc được, đừng bỏ vào đây file chứa mật khẩu/token.

```
docs/                              file .md của ba — GITIGNORE, nội dung cá nhân
tools/docs/mkdocs.yml              tên site, theme, extension markdown
tools/docs/overrides/partials/     ghi đè template theme (ẩn widget repo)
tools/proxy/conf.d/docs.conf       vhost: / -> zensical, /raw/ -> file gốc
```

Thêm tài liệu: bỏ file `.md` vào `docs/`, F5 — zensical watch thư mục, tự build lại.

- `docs/README.md` (hoặc `index.md`) là trang chủ. **Không có thì `/` trả 404.**
- Menu tự sinh theo thư mục. Tiêu đề = dòng `# ...` đầu file, không có thì lấy tên file.
- Nút tải (góc phải mỗi trang) trỏ `/raw/<file>.md` — nginx serve thẳng file gốc, không qua zensical.
- Tài liệu nằm chỗ khác: symlink vào `docs/`, hoặc đổi mount `../../docs` trong `docker-compose.yml` của tool này **và** của proxy (cho `/raw/`), rồi `make up`.
- Cập nhật: `make reup n=docs`.

Mấy chỗ dễ sai:

1. **Nút tải không phải code tự viết** — là nút "view" có sẵn của theme: lấy `edit_url` (= `repo_url` + `edit_uri` + file) rồi thay `/edit/` bằng `/raw/`. Vì vậy `mkdocs.yml` có `repo_url` dù không có repo; `repo_url` **không có `/` cuối**, không thì link thành `//raw/`.
2. **Mount lẻ `mkdocs.yml` + `overrides/`, không mount cả thư mục vào `/docs`.** Zensical bắt `docs_dir` nằm trong project root (`/docs`), mà `/docs` mount `:ro` thì docker không tạo được mountpoint con `/docs/content` — container không start.
3. **Zensical còn rất mới** (bản đã test: 0.0.65), image `latest`. Sau `make reup n=docs` mà trang lỗi thì xem `make logs n=docs` và [changelog](https://zensical.org/about/changelog/).
4. **`serve` là dev server** — image ghi rõ "không dành cho hosting". Đủ cho LAN, không đưa ra internet.
