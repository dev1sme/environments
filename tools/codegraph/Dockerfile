# install.sh chính thức tải bundle prebuilt (gồm Rust kernel), không cần Node.
# Chạy bằng uid host vì codegraph ghi <project>/.codegraph/ ra bind mount.

FROM debian:13-slim

ARG CODEGRAPH_VERSION=v1.6.0
ARG UID=1001
ARG GID=1001

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        procps \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd -g ${GID} cg && useradd -m -u ${UID} -g ${GID} cg
USER cg
ENV HOME=/home/cg
ENV PATH=/home/cg/.local/bin:${PATH}

RUN curl -fsSL https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh \
        | CODEGRAPH_VERSION=${CODEGRAPH_VERSION} sh \
    && codegraph version

# Container chỉ là chỗ chạy `docker exec`. State nằm trong <project>/.codegraph/
CMD ["sleep", "infinity"]
