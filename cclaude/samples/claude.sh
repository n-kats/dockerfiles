#!/bin/bash
cd "$(dirname "$0")/.." || exit 1

options=()
claude_env_file="_local/claude.env"
if [ -e "$claude_env_file" ]; then
  chmod 600 "$claude_env_file"
  options+=("--env-file" "$claude_env_file")
fi

litellm_url="${CLAUDE_LITELLM_URL:-}"
if [ -z "$litellm_url" ] && command -v lite-llm >/dev/null 2>&1; then
  litellm_url="$(lite-llm get-url --name private 2>/dev/null | head -n 1)"
fi
if [ -z "$litellm_url" ]; then
  litellm_url="http://127.0.0.1:4000"
fi

cclaude "$@" \
  --claude-json "_local/claude.json" \
  --setup "_local/setup_claude.sh" \
  "${options[@]}"
