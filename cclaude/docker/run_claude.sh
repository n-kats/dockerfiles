#!/bin/bash
set -euo pipefail

user_home="$(getent passwd "$(id -u)" | cut -d: -f6)"
if [ -n "${user_home:-}" ] && [ -x "$user_home/.local/bin/claude" ]; then
  exec "$user_home/.local/bin/claude" "$@"
fi

for candidate in /home/ubuntu/.local/bin/claude; do
  if [ -x "$candidate" ]; then
    exec "$candidate" "$@"
  fi
done

echo "[ERROR] claude executable not found for current user" >&2
exit 1
