# codegraph — code intelligence cho AI agent (https://github.com/colbymchenry/codegraph)
#
# Dùng install.sh chính thức, không dùng `npm i -g`: install.sh tải bundle
# prebuilt theo platform (gồm Rust kernel), không cần Node hay build tool.
#
# Chạy bằng uid host (1001 trên máy này, KHÔNG phải 1000 như starfish) vì codegraph ghi graph vào <project>/.codegraph/ — thư mục
# đó là bind mount ra host. Chạy root thì host (uid 1000) đọc không được, gặp EACCES.

FROM debian:13-slim

ARG CODEGRAPH_VERSION=v1.6.0
ARG UID=1001
ARG GID=1001

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        # codegraph đọc git để biết file nào đổi
        git \
        # socat không cần ở đây (relay là container riêng), nhưng procps cho pkill
        # — makefile dùng pkill để đổi project cho UI
        procps \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd -g ${GID} cg && useradd -m -u ${UID} -g ${GID} cg
USER cg
ENV HOME=/home/cg
ENV PATH=/home/cg/.local/bin:${PATH}

RUN curl -fsSL https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh \
        | CODEGRAPH_VERSION=${CODEGRAPH_VERSION} sh \
    && codegraph version

# Container này chỉ là chỗ chạy `docker exec`. State nằm hết trong
# <project>/.codegraph/ nên container không giữ gì, xoá dựng lại vô hại.
CMD ["sleep", "infinity"]
