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
RUN set -eux; \
  repo="n-kats/codex"; \
  tmp_dir="$(mktemp -d)"; \
  curl -fsSL -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/${repo}/releases/latest" >"${tmp_dir}/release.json"; \
  archive_count="$(jq '[.assets[]? | select(.name | endswith(".tar.gz"))] | length' "${tmp_dir}/release.json")"; \
  if [ "$archive_count" -ne 1 ]; then echo "Expected exactly 1 tar.gz asset in latest release, found: $archive_count" >&2; cat "${tmp_dir}/release.json" >&2; exit 1; fi; \
  url="$(jq -r '.assets[]? | select(.name | endswith(".tar.gz")) | .browser_download_url' "${tmp_dir}/release.json")"; \
  archive_path="${tmp_dir}/codex.tar.gz"; \
  curl -fL --retry 3 --retry-delay 2 -o "${archive_path}" "${url}"; \
  mkdir -p "${tmp_dir}/extract"; \
  tar -xzf "${archive_path}" -C "${tmp_dir}/extract"; \
  if [ -f "${tmp_dir}/extract/codex" ]; then \
    install -m 0755 "${tmp_dir}/extract/codex" /usr/local/bin/codex; \
  else \
    bin_path="$(find "${tmp_dir}/extract" -type f -name codex -perm -111 | head -n 1)"; \
    if [ -z "$bin_path" ]; then echo "'codex' binary not found in archive" >&2; exit 1; fi; \
    install -m 0755 "$bin_path" /usr/local/bin/codex; \
  fi; \
  setcap 'cap_setuid,cap_setgid=ep' /usr/local/bin/codex; \
  getcap /usr/local/bin/codex; \
  rm -rf "$tmp_dir"

USER ubuntu
COPY setup.sh /home/ubuntu/setup.sh
WORKDIR /workspace
CMD ["/bin/bash"]
