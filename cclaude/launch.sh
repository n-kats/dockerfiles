#!/bin/bash

if [ -z "$CLAUDE_CACHE_DIR" ]; then
  echo "[ERROR] CLAUDE_CACHE_DIR が設定されていません"
  exit 1
fi

this_script_dir="$(dirname "$(realpath "$0")")"
dockerfile_dir="${this_script_dir}/docker"
cache_dir="$(realpath -m "$CLAUDE_CACHE_DIR")"
mkdir -p "$cache_dir"
if [ ! -d "$cache_dir" ]; then
  echo "[ERROR] CLAUDE_CACHE_DIR がディレクトリではありません: $cache_dir"
  exit 1
fi
work_dir="$(pwd)"
cli_image_name="cclaude-cli"
build_cli=0
skip=0
show_help=0
show_init_help=0
do_init=0
DEFAULT_MODEL="gpt-5.2"
MODEL="$DEFAULT_MODEL"
LITELLM_URL=""
litellm_url_set=0
setup_script=""
env_file=""
claude_json=""
envs=()
volumes=()
options=()
input_tmpfile=""
if [ ! -t 0 ]; then
  input_tmpfile="$(mktemp)"
  cat - > "$input_tmpfile"
  trap 'rm -f "$input_tmpfile" >/dev/null 2>&1 || true' EXIT
fi

for arg in "$@"; do
  if [ "$skip" -eq 1 ]; then
    skip=0
    shift
    continue
  fi
  case $arg in
    --update)
      build_cli=1
      ;;
    --workdir)
      work_dir="$(realpath "$2")"
      skip=1
      ;;
    --setup)
      setup_script="$2"
      skip=1
      ;;
    --model)
      MODEL="${2:?Error: --model requires a value.}"
      skip=1
      ;;
    --litellm-url)
      LITELLM_URL="${2:?Error: --litellm-url requires a value.}"
      litellm_url_set=1
      skip=1
      ;;
    --env-file)
      env_file="${2:?Error: --env-file requires a value.}"
      skip=1
      ;;
    --claude-json)
      claude_json="${2:?Error: --claude-json requires a value.}"
      skip=1
      ;;
    -e|--env)
      envs+=("$2")
      skip=1
      ;;
    -v|--volume)
      volumes+=("$2")
      skip=1
      ;;
    --init)
      do_init=1
      ;;
    --init-help)
      show_init_help=1
      ;;
    --help)
      show_help=1
      options+=("$arg")
      ;;
    *)
      options+=("$arg")
      ;;
  esac
  shift
done

if [ "$show_init_help" -eq 1 ]; then
  samples_dir="${this_script_dir}/samples"
  echo "初期化手順:"
  echo "[.env, 秘密ファイル]"
  echo "- シンボリックリンクパターン: ln -s path/to/other/.env .env"
  echo "- 権限パターン: chmod 600 .env"
  echo ""
  echo "[_local/claude.sh]"
  cat "${samples_dir}/claude.sh"
  echo ""
  echo "[_local/claude.json]"
  cat "${samples_dir}/claude.json"
  echo ""
  echo "[_local/setup_claude.sh]"
  cat "${samples_dir}/setup_claude.sh"
  exit 0
fi

if [ "$do_init" -eq 1 ]; then
  samples_dir="${this_script_dir}/samples"
  local_dir="${work_dir}/_local"

  if [ ! -d "$work_dir" ]; then
    echo "[ERROR] 作業ディレクトリが存在しません: $work_dir"
    exit 1
  fi

  echo "[INFO] 初期化: $local_dir"
  mkdir -p "$local_dir"

  for file in claude.sh claude.json setup_claude.sh; do
    src="${samples_dir}/${file}"
    dst="${local_dir}/${file}"
    if [ -e "$dst" ]; then
      echo "[INFO] Skipping (already exists): $dst"
      continue
    fi
    cp "$src" "$dst"
    echo "[INFO] Created: $dst"
  done

  chmod +x "${local_dir}/claude.sh" "${local_dir}/setup_claude.sh" 2>/dev/null || true
  exit 0
fi

if [ ! -d "$work_dir" ]; then
  echo "[ERROR] 作業ディレクトリが存在しません: $work_dir"
  exit 1
fi

if [ -n "$env_file" ]; then
  if [[ "$env_file" == "~/"* ]]; then
    env_file="$HOME/${env_file#~/}"
  fi
  env_file="$(realpath -m "$env_file")"
  if [ ! -f "$env_file" ]; then
    echo "[ERROR] Envファイルが見つかりません: $env_file"
    exit 1
  fi
fi

if [ -n "$claude_json" ]; then
  if [[ "$claude_json" == "~/"* ]]; then
    claude_json="$HOME/${claude_json#~/}"
  fi
  claude_json="$(realpath -m "$claude_json")"
  if [ ! -f "$claude_json" ]; then
    echo "[ERROR] claude.json が見つかりません: $claude_json"
    exit 1
  fi
else
  claude_json="$cache_dir/mount/user/ubuntu/claude.json"
  claude_json_dir="$(dirname "$claude_json")"
  if [ ! -d "$claude_json_dir" ]; then
    echo "[INFO] Creating directory: $claude_json_dir"
    mkdir -p "$claude_json_dir"
  fi
  if [ ! -f "$claude_json" ]; then
    echo "[INFO] Creating file: $claude_json"
    printf '%s\n' '{}' > "$claude_json"
  fi
fi

# Build image automatically if it does not exist
if ! docker image inspect "$cli_image_name" >/dev/null 2>&1; then
  build_cli=1
fi

if [ "$build_cli" -eq 1 ]; then
  (
    set -e
    echo "[INFO] Building Claude CLI Docker image"
    docker build --build-arg TIMESTAMP=$(date +%Y%m%d_%H%M%S) -t "$cli_image_name" "$dockerfile_dir"
  )
fi

docker_options=()

if [ -n "$env_file" ]; then
  docker_options+=("--env-file" "$env_file")
fi

for env in "${envs[@]}"; do
  docker_options+=("-e" "$env")
done

for volume in "${volumes[@]}"; do
  docker_options+=("-v" "$volume")
done

if [ -n "$input_tmpfile" ]; then
  docker_options+=("-v" "$input_tmpfile:/tmp/claude_stdin:ro")
fi

mount_dir="$cache_dir/mount/user/ubuntu"
home_dir_in_docker="/home/ubuntu"

for dir in \
  claude_cache:.cache \
  claude_local:.local \
  claude_config:.claude \
  npm_cache:.npm \
  pnpm_cache:.pnpm-store \
  bun_cache:.bun \
; do
  IFS=":" read -r name path <<< "$dir"
  full_path="$mount_dir/$name"
  if [ ! -d "$full_path" ]; then
    echo "[INFO] Creating directory: $full_path"
    mkdir -p "$full_path"
  fi
  docker_options+=("-v" "$full_path:$home_dir_in_docker/$path")
done
docker_options+=("-v" "$claude_json:$home_dir_in_docker/.claude.json")

if [ "$show_help" -eq 1 ]; then
  cat << EOF
使い方: cclaude [--update] [--workdir <dir>] [--setup <script>] [--model <name>] [--litellm-url <url>] [--env-file <file>] [--claude-json <file>] [-e <VAR=VAL>] [-v <SRC:DEST>] [その他のclaudeオプション]

オプション:
  --update              Claude CLI のDockerイメージを更新して起動
  --workdir <dir>       対象ディレクトリ（デフォルトはカレントディレクトリ）
  --setup <script>      起動時に実行するセットアップスクリプト
  --model <name>        使用するモデル名（デフォルトは gpt-5.2）
  --litellm-url <url>   LiteLLM のベースURL（指定時のみLiteLLM経由にする）
  --env-file <file>     Dockerコンテナに環境変数を渡す
  --claude-json <file>  claude.json を指定してマウントする
  -e, --env <VAR=VAL>   Dockerコンテナに環境変数を渡す
  -v, --volume <SRC:DEST> Dockerコンテナにボリュームをマウントする
  --init                _local/ に設定ファイルを作成（既存はスキップ）
  --init-help           初期化手順のヘルプを表示
  --help                このヘルプメッセージとclaudeのヘルプを表示
EOF
fi

if [ -n "$input_tmpfile" ]; then
  docker_options+=("-i")
else
  docker_options+=("-it")
fi

if [ "$litellm_url_set" -eq 1 ] && [ -n "$LITELLM_URL" ]; then
  docker_options+=("-e" "ANTHROPIC_BASE_URL=$LITELLM_URL")
fi

command_str="claude --model \"$MODEL\" ${options[@]}"

docker run --rm \
  -v "$work_dir:/workspace" \
  -w "/workspace" \
  -u "$(id -u):$(id -g)" \
  --network host \
  "${docker_options[@]}" \
  "$cli_image_name" bash -c "
if [ -n \"$setup_script\" ]; then
  if [ -f \"$setup_script\" ]; then
    echo \"[INFO] Running setup script: $setup_script\" 1>&2
    source \"$setup_script\" 1>&2
  else
    echo \"[ERROR] Setup script not found: $setup_script\" 1>&2
    exit 1
  fi
fi

if [ -n \"$input_tmpfile\" ]; then
  cat /tmp/claude_stdin | ${command_str}
else
  ${command_str}
fi
"
