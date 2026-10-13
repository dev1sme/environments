# codegraph — container hoá

https://github.com/colbymchenry/codegraph

Code intelligence cho AI agent: index codebase thành graph SQLite, agent gọi qua MCP để lấy symbol + call path trong 1 round-trip thay vì grep + Read nhiều lần.

Repo gốc **không có Dockerfile, không có docker-compose** — cách cài chính thức là `install.sh` tải bundle prebuilt. Thư mục này container hoá nó.

## Chạy gì

```bash
make up                          # bat ca env, lan dau tu build image codegraph
make reup n=codegraph            # rebuild sau khi sua Dockerfile
make down n=codegraph            # tat rieng codegraph
make cg-index p=<project>        # init + index lan dau, re-index lan sau
make cg-status p=<project>       # xem trang thai index
make cg-mcp p=<project>          # in config MCP de dan vao .mcp.json
make cg-upgrade                  # build ban release moi nhat, sau do re-index
make cg-reindex-all              # re-index moi project da co .codegraph/
```

Đường dẫn `p=` là **tương đối trong `PROJECTS_ROOT`** (khai ở `.env` gốc repo).

## MCP config

`make cg-mcp p=<project>` in ra, dán vào `.mcp.json` của project:

```json
{
  "mcpServers": {
    "codegraph": {
      "command": "docker",
      "args": ["exec", "-i", "-w", "<PROJECTS_ROOT>/<project>",
               "env-codegraph", "codegraph", "serve", "--mcp"]
    }
  }
}
```

`serve --mcp` là stdio transport, agent spawn 1 lần lúc mở session rồi giữ suốt. Tool call sau đó đi qua pipe đã mở — **không** spawn container mỗi lần gọi.

## 5 chỗ đã đâm phải, ghi lại để khỏi đâm lại

### 1. `user` phải khớp uid host — máy này là **1001**, không phải 1000

codegraph ghi graph vào `<project>/.codegraph/`, đó là bind mount ra host. Sai uid:

```
Failed: EACCES: permission denied, mkdir '<project>/.codegraph'
```

Đừng hardcode `1000` — đó là số hay thấy trong ví dụ trên mạng, nhưng máy này `id -u` = 1001. Khai ở `.env`: `HOST_UID` / `HOST_GID`.

### 2. Mount TRÙNG đường dẫn host, không phải `/workspace`

```yaml
volumes:
  - ${PROJECTS_ROOT}:${PROJECTS_ROOT}
```

MCP mode lấy project path từ `rootUri` client gửi. Claude Code chạy trên host nên gửi đường dẫn host. Mount vào `/workspace` là container không có path đó.

Mount vào `/workspace` rồi truyền biến chỉ project cũng chạy được, nhưng phải khai project mỗi lần gọi. Mount trùng path thì khỏi.

### 3. Compose riêng, root `include` vào — không gọi bằng `-f`

Root `docker-compose.yml`:

```yaml
include:
  - path: tools/codegraph/docker-compose.yml
    env_file: .env
```

Cùng 1 compose project nên `docker compose ps` thấy hết, và gọi bằng tên service (`docker compose up -d codegraph`), không cần `-f`.

**Vì sao không dùng `-f`:** `docker compose -f <path>` đọc `.env` cạnh **file compose**, không phải ở CWD. Thiếu `--env-file` là `${PROJECTS_ROOT}` rỗng, mount thành `:`:

```
invalid mount config for type "volume": invalid mount path: ':' mount path must be absolute
```

`include` + `env_file: .env` giải quyết gọn hơn là nhớ truyền `--env-file` mỗi lệnh.

**Bẫy A — đừng để `external: true` trong file được include.** Hai khai báo network bị merge, có `external: true` là network gộp thành external, `make up` trên máy mới báo:

```
network env-net declared as external, but could not be found
```

File này khai `name: env-net` giống hệt root, không `external`.

**Bẫy B — đổi từ `-f` sang `include` là đổi compose project name.** Trước đó project là `codegraph` (theo tên thư mục), sau khi include thì thành `environments`. Container cũ trở thành mồ côi và đụng tên:

```
Conflict. The container name "/env-codegraph" is already in use
```

Phải `docker rm -f env-codegraph` một lần khi chuyển.

### 4. `docker exec -i`, KHÔNG `-it`

TTY chèn ký tự vào stream và làm hỏng framing JSON-RPC của MCP.

### 5. `-w <project>` để có default project

Không có `-w`, server trả về:

> This server started somewhere with no `.codegraph/` of its own, so there is no default project

Tool vẫn dùng được nhưng mỗi call phải tự truyền `projectPath`. Có `-w` thì project đó thành default.

## Telemetry

**Mặc định BẬT.** Verified trong code, không chỉ đọc doc:

```
src/telemetry/index.ts:185       DO_NOT_TRACK=1 > CODEGRAPH_TELEMETRY=0|1 > stored config > default on
src/telemetry/index.ts:30        TELEMETRY_ENDPOINT = 'https://telemetry.getcodegraph.com/v1/events'
src/upgrade/update-check.ts:90   return envTruthy(env.CODEGRAPH_NO_UPDATE_CHECK) || envTruthy(env.DO_NOT_TRACK);
```

Gửi: `machine_id` (UUID random), version, os/arch, node major, tên command/tool đã chạy, tên ngôn ngữ đã index, số file dạng khoảng, tên agent từ MCP handshake. Gộp theo ngày. Không gửi source code, tên file, tên repo, symbol, search query, IP.

Compose set `CODEGRAPH_TELEMETRY=0` — **tắt telemetry, giữ update check**. Không dùng `DO_NOT_TRACK=1` vì nó tắt luôn update check (dòng `update-check.ts:90`).

Kiểm tra:

```bash
docker exec env-codegraph codegraph telemetry status
# Telemetry: disabled (CODEGRAPH_TELEMETRY environment variable)
```

## UI đang TẮT — `ui` chưa có trong release

Kiểm tra 2026-09-07: release mới nhất là **v1.6.0**, không có lệnh `ui`:

```
$ docker exec env-codegraph codegraph ui
error: unknown command 'ui'
```

`ui` chỉ có trên branch `main` (`src/bin/codegraph.ts:1872`), chưa cắt release.

Bật lại khi có release chứa `ui`:

```bash
# 1. them service relay vao docker-compose.yml:
#      relay:
#        image: alpine/socat
#        network_mode: "service:codegraph"
#        command: TCP-LISTEN:8080,fork,reuseaddr TCP:127.0.0.1:4747
# 2. doi ten vhost
mv tools/proxy/conf.d/codegraph.conf.dist tools/proxy/conf.d/codegraph.conf
make cg-auth u=<user>     # basic auth, UI lo cau truc source code — khong truyen pw= thi no hoi, khong vao shell history
make up && make reload
```

Vì sao cần socat relay: `codegraph ui` bind cứng `127.0.0.1` (`src/ui-server/constants.ts:21`), chỉ có `--port`, **không có `--host`**. Container khác không với tới loopback của container này. socat chạy `network_mode: "service:codegraph"` nên share netns, thấy đúng loopback đó rồi mở 8080 ra `env-net`.

Và `ui` không có flag `--path` (chỉ `--port` / `--no-open` / `--read-only`) — nó lấy project từ cwd. Nên 1 process = 1 project, phải đổi bằng `docker exec -w`.

## Ghi chú khác

- `.codegraph/` mọc ra trong mọi project được index (~5MB cho project 140 file). Nên thêm vào `.gitignore` của từng project. [Chưa xác minh] chưa rõ `codegraph init` có tự thêm hay không.
- Container không giữ state — xoá dựng lại vô hại, graph nằm trong project dir.
- Base image `debian:13-slim`. Ban đầu dùng `debian:12-slim`, đổi vì Docker DX báo 2 critical + 8 high vulnerabilities.
