FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Tokyo \
    LANG=C.UTF-8 \
    PATH=/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    PLAYWRIGHT_BROWSERS_PATH=/ms-playwright \
    BUN_INSTALL=/usr/local/bun

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git gh jq ca-certificates libcap2-bin ripgrep unzip xz-utils \
    make sudo chromium-browser \
    python3 python3-pip python3-venv pipx \
    build-essential graphviz-dev pkg-config \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
 && apt-get install -y nodejs \
 && rm -rf /var/lib/apt/lists/*

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
  npx --yes playwright install --with-deps; \
  chmod -R a+rX "$PLAYWRIGHT_BROWSERS_PATH"

RUN set -eux; \
  if ! getent group ubuntu >/dev/null; then groupadd -g 1000 ubuntu; fi; \
  if ! id -u ubuntu >/dev/null 2>&1; then useradd -m -u 1000 -g ubuntu -s /bin/bash ubuntu; fi

RUN groupadd -g 1500 assistant \
 && useradd -m -u 1500 -g 1500 -s /bin/bash assistant \
 && usermod -aG ubuntu assistant

RUN set -eux; \
  printf '%s\n' 'ubuntu ALL=(assistant) NOPASSWD:ALL' >/etc/sudoers.d/ubuntu-as-assistant; \
  chmod 0440 /etc/sudoers.d/ubuntu-as-assistant; \
  visudo -cf /etc/sudoers.d/ubuntu-as-assistant

ARG TIMESTAMP=YYYYMMDD_HHMMSS
RUN touch /build_timestamp_$TIMESTAMP
RUN npm install -g @anthropic-ai/claude-code

USER ubuntu
COPY setup.sh /home/ubuntu/setup.sh
WORKDIR /workspace
CMD ["/bin/bash"]
