FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Tokyo \
    LANG=C.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git ca-certificates ripgrep unzip xz-utils \
    make sudo chromium-browser \
    python3 python3-pip python3-venv pipx \
    build-essential graphviz-dev pkg-config \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
 && apt-get install -y nodejs \
 && rm -rf /var/lib/apt/lists/*

RUN corepack enable \
 && corepack prepare pnpm@latest --activate

ARG TIMESTAMP=YYYYMMDD_HHMMSS
RUN touch /build_timestamp_$TIMESTAMP
RUN npm install -g @openai/codex

USER ubuntu
COPY setup.sh /home/ubuntu/setup.sh
WORKDIR /workspace
CMD ["/bin/bash"]
