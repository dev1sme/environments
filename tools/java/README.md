# Java multi-version dev (JDK 8 + JDK 21) qua Dev Containers

Máy host cài sẵn cả JDK 8 và JDK 21, phải switch qua lại (`sdkman`/`jenv`/`update-alternatives`) mỗi lần mở project khác nhóm version — bất tiện, dễ quên switch dẫn tới build sai version.

Dev Containers giải quyết: mỗi project tự pin JDK version trong container riêng, VSCode tự "nhảy vào" đúng container khi mở project, không cần switch gì trên host nữa. Mở song song 2 project khác version cùng lúc cũng không conflict vì mỗi container độc lập.

**Đây là tài liệu hướng dẫn — không phải tool tự chạy.** Áp dụng thủ công cho từng project theo các bước dưới.

## Prerequisite

- Docker (đã có: `docker --version` → 29.7.2)
- VSCode extension: `ms-vscode-remote.remote-containers` ("Dev Containers")

## Kiểm kê project hiện có trên máy

| Project | Path | Java | Build tool | Ghi chú |
|---|---|---|---|---|
| demo-microservices | `dev/project/thomson/demo-microservices` | 21 | Gradle | đã có `docker-compose.yml` + `.vscode` — multi-service, cần review kỹ trước khi thêm devcontainer |
| demo | `dev/project/thomson/demo` | 21 | Gradle | |
| project-member-status/backend | `dev/project/thomson/project-member-status/backend` | 21 | Gradle | |
| server-indie | `dev/project/dev1sme/server-indie` | 21 | Gradle | |
| cba-tracking/backend | `dev/project/thomson/cba-tracking/backend` | 21 | Gradle | ứng viên pilot — đơn giản, chưa có Dockerfile sẵn |
| e-commerce/backend | `dev/project/dev1sme/e-commerce/backend` | 21 | Gradle (kts) | |
| mp-winboard-backend | `dev/project/thomson/sa-winboard-claude/mp-winboard-backend` | 8 | Maven | |
| sa-winboard-backend | `dev/project/thomson/sa-winboard-claude/sa-winboard-backend` | 8 | Maven | ứng viên pilot — chưa có Dockerfile sẵn |
| bizco/icms | `dev/project/thomson/bizco/icms` | 8 | Maven | đã có sẵn `Dockerfile` + `docker-compose.yml` — review trước khi quyết định tái dùng hay viết devcontainer riêng |

## Bước áp dụng cho 1 project

### 1. Tạo `.devcontainer/devcontainer.json` trong project

**Project Gradle, Java 21:**

```json
{
  "name": "java21-gradle",
  "image": "mcr.microsoft.com/devcontainers/java:21",
  "customizations": {
    "vscode": {
      "extensions": ["vscjava.vscode-java-pack"]
    }
  },
  "mounts": [
    "source=gradle-cache,target=/home/vscode/.gradle,type=volume"
  ]
}
```

**Project Maven, Java 8:**

```json
{
  "name": "java8-maven",
  "image": "mcr.microsoft.com/devcontainers/java:8",
  "customizations": {
    "vscode": {
      "extensions": ["vscjava.vscode-java-pack"]
    }
  },
  "mounts": [
    "source=maven-repo,target=/home/vscode/.m2,type=volume"
  ]
}
```

Volume `gradle-cache` / `maven-repo` đặt tên cố định, dùng chung giữa mọi project cùng build tool — tránh tải lại dependency mỗi lần mở project khác.

### 2. Mở project trong container

VSCode mở folder project → Command Palette → **Dev Containers: Reopen in Container**.

### 3. Verify

- `./gradlew build` (hoặc `mvn compile`) chạy được trong terminal tích hợp.
- Java extension nhận đúng SDK version (check status bar góc dưới).
- Đặt breakpoint, F5 debug hoạt động.

### 4. Case đặc biệt — project đã có Dockerfile riêng (`icms`)

Không viết devcontainer từ đầu ngay — đọc `Dockerfile`/`docker-compose.yml` hiện có trước, cân nhắc dùng `"dockerComposeFile"` trong `devcontainer.json` trỏ vào compose có sẵn thay vì tạo image mới trùng lặp.

## Ghi chú khác

- IntelliJ không có "Reopen in Container" 1-click như VSCode. Muốn dùng JDK trong container: Project Structure → SDK → trỏ Docker remote JDK, hoặc dùng JetBrains Gateway.
- Nếu project dev cần Postgres, tham khảo `tools/postgres/` ở root repo này — join network `env-net` để dùng chung instance thay vì dựng DB riêng trong devcontainer.
