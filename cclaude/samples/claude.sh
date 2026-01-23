#!/bin/bash
cd "$(dirname "$0")/.." || exit 1
eval "CLAUDE_COMMON_ARGS=(${CLAUDE_COMMON_ARGS_STR})"

options=()
if [ -e ".env" ]; then
  chmod 600 .env
  options+=("--env-file" ".env")
fi

litellm_url="${CLAUDE_LITELLM_URL:-}"
if [ -z "$litellm_url" ] && command -v lite-llm >/dev/null 2>&1; then
  litellm_url="$(lite-llm get-url --name private 2>/dev/null | head -n 1)"
fi
if [ -z "$litellm_url" ]; then
  litellm_url="http://127.0.0.1:4000"
fi

cclaude "$@" "${CLAUDE_COMMON_ARGS[@]}" \
  --model "gpt-5.2" \
  --litellm-url "$litellm_url" \
  --claude-json "_local/claude.json" \
  --setup "_local/setup_claude.sh" \
  "${options[@]}"
