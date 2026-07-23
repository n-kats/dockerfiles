#!/bin/bash
set -euo pipefail

if [ -x /opt/claude-code/bin/claude ]; then
  exec /opt/claude-code/bin/claude "$@"
fi

echo "[ERROR] claude executable not found for current user" >&2
exit 1
