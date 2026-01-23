#!/bin/bash
cd "$(dirname "$0")/.." || exit 1
eval "CODEX_COMMON_ARGS=(${CODEX_COMMON_ARGS_STR})"

options=()
if [ -e ".env" ]; then
  chmod 600 .env
  options+=("--env-file" ".env")
fi
mkdir -p _local/codex_homes
chmod 700 _local/codex_homes

ccodex "$@" "${CODEX_COMMON_ARGS[@]}" \
  --codex-home _local/codex_homes \
  --config _local/codex.toml \
  --setup _local/setup.sh \
  "${options[@]}"
