FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Tokyo \
    LANG=C.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git ca-certificates unzip xz-utils \
    python3 python3-pip python3-venv pipx \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
 && apt-get install -y nodejs \
 && rm -rf /var/lib/apt/lists/*

RUN corepack enable \
 && corepack prepare pnpm@latest --activate \
 && curl -fsSL https://bun.sh/install | bash \
 && curl -LsSf https://astral.sh/uv/install.sh | sh

RUN npx --yes playwright install --with-deps chromium

ARG TIMESTAMP=YYYYMMDD_HHMMSS
RUN touch /build_timestamp_$TIMESTAMP
RUN npm install -g @openai/codex

WORKDIR /workspace
CMD ["/bin/bash"]
