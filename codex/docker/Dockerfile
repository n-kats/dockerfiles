FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Tokyo \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    LESSCHARSET=utf-8 \
    PATH=/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    PLAYWRIGHT_BROWSERS_PATH=/ms-playwright \
    BUN_INSTALL=/usr/local/bun

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    bubblewrap \
    build-essential \
    ca-certificates \
    chromium-browser \
    curl \
    gawk \
    gh \
    git \
    git-lfs \
    graphviz-dev \
    fd-find \
    less \
    jq \
    libcap2-bin \
    fzf \
    make \
    pipx \
    pkg-config \
    python3 \
    python3-pip \
    python3-venv \
    ripgrep \
    zip \
    tree \
    unzip \
    xz-utils \
 && curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
 && apt-get install -y nodejs \
 && ln -sf /usr/bin/fdfind /usr/local/bin/fd \
 && git lfs install --system \
 && rm -rf /var/lib/apt/lists/*

RUN git config --system i18n.commitEncoding utf-8 \
 && git config --system i18n.logOutputEncoding utf-8 \
 && git config --system --add safe.directory /workspace

RUN corepack enable \
 && corepack prepare pnpm@latest --activate

RUN set -eux; \
  mkdir -p "$PLAYWRIGHT_BROWSERS_PATH" "$BUN_INSTALL" /usr/local/bin; \
  chmod 0755 "$PLAYWRIGHT_BROWSERS_PATH" "$BUN_INSTALL" /usr/local/bin

RUN set -eux; \
  curl -LsSf https://astral.sh/uv/install.sh | sh; \
  install -m 0755 /root/.local/bin/uv /usr/local/bin/uv; \
  if [ -f /root/.local/bin/uvx ]; then install -m 0755 /root/.local/bin/uvx /usr/local/bin/uvx; fi; \
  rm -rf /root/.local

RUN set -eux; \
  curl -fsSL https://bun.sh/install | bash; \
  ln -sf "$BUN_INSTALL/bin/bun" /usr/local/bin/bun; \
  ln -sf "$BUN_INSTALL/bin/bunx" /usr/local/bin/bunx

RUN set -eux; \
  export DENO_INSTALL=/usr/local/deno; \
  curl -fsSL https://deno.land/install.sh | sh; \
  ln -sf "$DENO_INSTALL/bin/deno" /usr/local/bin/deno

RUN set -eux; \
  npx --yes playwright install --with-deps; \
  chmod -R a+rX "$PLAYWRIGHT_BROWSERS_PATH"

RUN set -eux; \
  if ! getent group ubuntu >/dev/null; then groupadd -g 1000 ubuntu; fi; \
  if ! id -u ubuntu >/dev/null 2>&1; then useradd -m -u 1000 -g ubuntu -s /bin/bash ubuntu; fi

ARG TIMESTAMP=YYYYMMDD_HHMMSS
RUN touch /build_timestamp_$TIMESTAMP
RUN npm install -g @openai/codex

USER ubuntu
COPY setup.sh /home/ubuntu/setup.sh
WORKDIR /workspace
CMD ["/bin/bash"]
