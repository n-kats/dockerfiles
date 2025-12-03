#!/bin/bash

if [ -z "$GEMINI_CLI_CACHE_DIR" ]; then
  echo "GEMINI_CLI_CACHE_DIR is not set"
  exit 1
fi

dockerfile_dir="$(dirname "$(realpath "$0")")/docker"
cache_dir="$(realpath "$GEMINI_CLI_CACHE_DIR")"
work_dir="$(pwd)"
docker_options=()
build=0
skip=0
show_help=0
for arg in "$@"; do
  if [ "$skip" -eq 1 ]; then
    skip=0
    shift
    continue
  fi
  case $arg in
    --update)
      build=1
      ;;
    --workdir)
      work_dir="$(realpath "$2")"
      skip=1
      ;;
    --setup)
      setup_script="$2"
      skip=1
      ;;
    -e|--env)
      docker_options+=("-e" "$2")
      skip=1
      ;;
    -v|--volume)
      docker_options+=("-v" "$2")
      skip=1
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

if [ ! -d $work_dir ]; then
  echo "[ERROR] Work directory does not exist: $work_dir"
  exit 1
fi

if ! docker image inspect my-gemini-cli >/dev/null 2>&1; then
  build=1
fi

if [ "$build" -eq 1 ]; then
  set -e
  (
    echo "[INFO] Building Docker image"
    docker build --build-arg TIMESTAMP=$(date +%Y%m%d_%H%M%S) -t my-gemini-cli "$dockerfile_dir"
  )
fi

mount_dir="$cache_dir/mount/user/ubuntu"
home_dir_in_docker="/home/ubuntu"

for dir in \
  gemini_cli_cache:.cache \
  gemini_cli_local:.local \
  gemini_cli_config:.gemini \
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


if [ "$show_help" -eq 1 ]; then
  cat << EOF
使い方: gemini [--update] [--workdir <dir>] [--setup <script>] [-e <VAR=VAL>] [-v <SRC:DEST>] [その他のgeminiオプション]

オプション:
  --update              gemini用Dockerイメージを更新して起動
  --workdir <dir>       対象ディレクトリ（デフォルトはカレントディレクトリ）
  --setup <script>      起動時に実行するセットアップスクリプト
  -e, --env <VAR=VAL>   Dockerコンテナに環境変数を渡す
  -v, --volume <SRC:DEST> Dockerコンテナにボリュームをマウントする
  --help                このヘルプメッセージとgeminiのヘルプを表示
EOF
fi

command_str="gemini ${options[@]}"
docker run --rm -it \
  -v "$work_dir:/workspace" \
  -w "/workspace" \
  -u "$(id -u):$(id -g)" \
  --network host \
  "${docker_options[@]}" \
  my-gemini-cli bash -c "
if [ -n \"$setup_script\" ]; then
  if [ -f \"$setup_script\" ]; then
    echo \"[INFO] Running setup script: $setup_script\"
    source \"$setup_script\"
  else
    echo \"[ERROR] Setup script not found: $setup_script\"
    exit 1
  fi
fi
alias apply_patch=patch

${command_str}
"
