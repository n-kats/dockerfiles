#!/bin/bash
source "$HOME/.bashrc"
export PATH="/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$HOME/.local/bin:$PATH"
export UV_LINK_MODE="${UV_LINK_MODE:-copy}"
export UV_PROJECT_ENVIRONMENT="_cache/codex_venv"
export UV_CACHE_DIR="_cache/uv_cache"
mkdir -p "$(dirname "$UV_PROJECT_ENVIRONMENT")" "$UV_CACHE_DIR"
chmod 0777 "$(dirname "$UV_PROJECT_ENVIRONMENT")" "$UV_CACHE_DIR" 2>/dev/null || true
if [ ! -e "$UV_PROJECT_ENVIRONMENT" ]; then
  uv venv "$UV_PROJECT_ENVIRONMENT"
  chmod -R a+rwX "$UV_PROJECT_ENVIRONMENT" 2>/dev/null || true
fi
source "$UV_PROJECT_ENVIRONMENT/bin/activate"
uv sync --dev --active
