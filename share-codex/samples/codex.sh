#!/bin/bash
cd "$(dirname "$0")/.." || exit 1

options=()
if [ -e ".env" ]; then
  chmod 600 .env
  options+=("--env-file" ".env")
fi
mkdir -p _local/codex_homes
chmod 700 _local/codex_homes
share-codex "$@" \
  --config-file _local/codex.toml \
  --codex-home _local/codex_homes \
  --setup _local/setup.sh \
  "${options[@]}"
