# mm — help / menu cho makefile bất kỳ

Viết chú thích `##` ngay tại target là có `make help`, `make menu` (giao diện chọn lệnh, tự hỏi biến), `make help-check`, `make help-doc` (sinh `MAKEFILE.md`). Không copy file sang project khác.

## Cài một lần

```bash
tools/make/install.sh
# ~/.local/bin/mm           -> tools/make/mm
# ~/.local/share/make-menu  -> tools/make/
```

Cần bash >= 4 (macOS: `brew install bash`).

## Dùng trong project

Thêm 1 dòng vào makefile:

```make
-include $(HOME)/.local/share/make-menu/menu.mk
.DEFAULT_GOAL := help     # tuỳ chọn: `make` không tham số = help
```

Hoặc không đụng makefile: chạy `mm`, `mm help`, `mm check`, `mm doc` ở thư mục có makefile.

`menu.mk` không đổi default goal của makefile include nó.

## Cú pháp

```make
#!var n       | Service (n) | docker compose config --services
#!var p@cg-*  | Project (p) | ls "$PROJECTS_ROOT"
#!var force   | Ghi đè?     | confirm
#!var pw      |             | skip

##@ Core
up:              ## bật hết
	docker compose up -d
logs:            ## n=proxy | xem log (follow)
	docker compose logs -f $(n)
cert-init:       ## [d=...] [force=1] | sinh cert
	...
domain-set:      ## d=new.local | ⚠ đổi domain nội bộ
	...
build:           # không có ## -> ẩn khỏi help/menu
	...
```

| Dòng | Ý nghĩa |
|---|---|
| `##@ Tên` | tiêu đề nhóm cho các target phía dưới |
| `target: ## mô tả` | hiện trong help/menu |
| `target: ## x=vd [y=vd] \| mô tả` | có biến: `x` bắt buộc (menu hỏi), `[y]` tuỳ chọn. Bên trái `\|` phải toàn là biến |
| mô tả bắt đầu `⚠` | hiện màu vàng, cho lệnh nguy hiểm |
| target không có `##` | ẩn (`make help-check` liệt kê để khỏi quên) |
| `#!var tên[@glob] \| tiêu đề \| nguồn` | cách menu hỏi biến `tên` |

Nguồn của `#!var`:

- lệnh shell: mỗi dòng stdout là 1 gợi ý (thêm `\t tag` nếu muốn). Chạy ở thư mục hiện tại, đã nạp `.env`. Được dùng `|` thoải mái.
- `confirm`: hỏi Có/Không, Có thì truyền `tên=vd`.
- `skip`: không hỏi (target tự hỏi, vd password).
- để trống: nhập tay.
- `@glob`: chỉ áp cho target khớp glob. Dòng khớp đầu tiên thắng, nên để cụ thể lên trước.

Biến không có `#!var` thì menu cho nhập tay, tiêu đề là tên biến.

## MAKEFILE.md

`make help-doc` sinh `MAKEFILE.md` cạnh makefile để xem trên GitHub/IDE. Nếu `MAKEFILE.md` tồn tại, `make help-check` báo lỗi khi nó lệch với makefile. Project không muốn thì không sinh, check bỏ qua.

## File

| File | |
|---|---|
| `mm` | entrypoint, tìm makefile, gọi script tương ứng |
| `lib.sh` | parser chú thích `##`, dùng chung |
| `menu.sh` `help.sh` `check.sh` `doc.sh` | từng lệnh |
| `menu.mk` | target help/menu/help-check/help-doc để include |
| `install.sh` | symlink vào `~/.local` |
