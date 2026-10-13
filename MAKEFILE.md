<!-- Sinh bởi `mm doc` từ Makefile — sửa chú thích ## trong Makefile rồi chạy `make help-doc`, không sửa file này. -->

# make · environments

Chạy `make menu` để chọn lệnh bằng giao diện, hoặc `make <target> [biến=giá-trị]`.
Biến trong `[ ]` là tuỳ chọn.

## Core

| Target | Biến        | Mô tả                                                                  |
| ------ | ----------- | ---------------------------------------------------------------------- |
| `up`   |             | bật proxy + postgres + mongodb + coredns + homepage + docs + codegraph |
| `down` | `[n=proxy]` | tắt 1 service, trống = tắt hết                                         |
| `reup` | `n=proxy`   | pull bản mới / rebuild + up 1 service                                  |
| `logs` | `[n=proxy]` | xem log (follow), trống = mọi service                                  |
| `ls`   |             | liệt kê container đang chạy                                            |
| `bash` | `n=proxy`   | vào shell container                                                    |

## Proxy

| Target   | Biến | Mô tả                           |
| -------- | ---- | ------------------------------- |
| `reload` |      | reload nginx, KHÔNG đứt kết nối |

## Portability

| Target       | Biến                  | Mô tả                                                 |
| ------------ | --------------------- | ----------------------------------------------------- |
| `domain-set` | `d=new.local`         | ⚠ đổi domain nội bộ (sed toàn repo, cần commit trước) |
| `cert-init`  | `[d=...]` `[force=1]` | sinh CA riêng + wildcard cert                         |
| `cert`       |                       | xem cert hiện tại                                     |

## DNS

| Target     | Biến | Mô tả                                |
| ---------- | ---- | ------------------------------------ |
| `dns-init` |      | sinh zone file từ HOST_IP trong .env |
| `dns-test` |      | dig thử 1 domain qua coredns         |

## DB

| Target          | Biến         | Mô tả                                            |
| --------------- | ------------ | ------------------------------------------------ |
| `psql`          |              | vào psql                                         |
| `db`            | `name=myapp` | tạo database cho app                             |
| `db-dump`       |              | pg_dumpall + gzip ra .data/dump/                 |
| `db-restore`    | `f=<file>`   | ⚠ restore (chỉ trên cluster mới init)            |
| `mongosh`       |              | vào mongosh                                      |
| `mongo-dump`    |              | mongodump --archive --gzip ra .data/dump/        |
| `mongo-restore` | `f=<file>`   | restore archive (không --drop, trùng _id bỏ qua) |

## codegraph

| Target       | Biến                  | Mô tả                                |
| ------------ | --------------------- | ------------------------------------ |
| `cg-auth`    | `u=<user>` `[pw=...]` | sinh htpasswd cho UI                 |
| `cg-index`   | `p=<project>`         | index 1 project                      |
| `cg-status`  | `p=<project>`         | trạng thái index                     |
| `cg-mcp`     | `p=<project>`         | in config MCP                        |
| `cg-upgrade` |                       | build codegraph bản release mới nhất |

## Biến

Menu lấy gợi ý từ lệnh nguồn (chạy ở thư mục repo, đã nạp `.env`).

| Biến    | Áp cho | Tiêu đề                        | Nguồn                                                                                                |
| ------- | ------ | ------------------------------ | ---------------------------------------------------------------------------------------------------- |
| `n`     |        | Service (n)                    | `docker compose config --services`                                                                   |
| `p`     | `cg-*` | Project (p)                    | `find "$PROJECTS_ROOT" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' \| sort`                       |
| `name`  |        | Tên database (name)            | nhập tay                                                                                             |
| `f`     |        | File dump (f)                  | `ls -1t .data/dump/* \| while read -r f; do printf '%s\t%s\n' "$f" "$(du -h "$f" \| cut -f1)"; done` |
| `d`     |        | Domain (d)                     | nhập tay                                                                                             |
| `u`     |        | User (u)                       | nhập tay                                                                                             |
| `force` |        | Ghi đè cert đang có? (force=1) | hỏi Có/Không                                                                                         |
| `pw`    |        |                                | không hỏi                                                                                            |
