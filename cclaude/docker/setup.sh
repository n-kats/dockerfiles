#!/bin/bash
set -euo pipefail

if command -v npx >/dev/null 2>&1; then
  npx --yes playwright install
fi
