#!/bin/bash

if [ -z "$CODEX_CACHE_DIR" ]; then
  echo "CODEX_CACHE_DIR is not set"
  exit 1
fi

dockerfile_dir="$(dirname "$(realpath "$0")")/docker"
cache_dir="$(realpath "$CODEX_CACHE_DIR")"
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
      setup_script="$(realpath "$2")"
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
    --api)
      use_api_key=1
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

if [ "$build" -eq 1 ]; then
  set -e
  (
    echo "[INFO] Building Docker image"
    docker build --build-arg TIMESTAMP=$(date +%Y%m%d_%H%M%S) -t my-codex "$dockerfile_dir"
  )
fi

mount_dir="$cache_dir/mount/user/ubuntu"
home_dir_in_docker="/home/ubuntu"
if [ "$use_api_key" -eq 1 ]; then
  codex_dir_name="codex_with_api_key"
  mount_cache_dir="cach_with_api_key"
  mount_local_dir="local_with_api_key"
  docker_options+=("-e" "OPENAI_API_KEY=$OPENAI_API_KEY")
else
  codex_dir_name="codex"
  mount_cache_dir="cache"
  mount_local_dir="local"
fi

for dir in \
  $mount_cache_dir:.cache \
  $mount_local_dir:.local \
  $codex_dir_name:.codex \
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
使い方: codex [--update] [--workdir <dir>] [--setup <script>] [-e <VAR=VAL>] [-v <SRC:DEST>] [その他のcodexオプション]

オプション:
  --update              codexを更新して起動
  --workdir <dir>       対象ディレクトリ（デフォルトはカレントディレクトリ）
  --setup <script>      起動時に実行するセットアップスクリプト
  -e, --env <VAR=VAL>   Dockerコンテナに環境変数を渡す
  -v, --volume <SRC:DEST> Dockerコンテナにボリュームをマウントする
  --api                 OpenAI APIキーを使用（環境変数OPENAI_API_KEYが必要）
  --help                このヘルプメッセージとcodexのヘルプを表示
EOF
fi

docker run --rm -it \
  -v "$work_dir:/workspace" \
  -w "/workspace" \
  -u "$(id -u):$(id -g)" \
  --network host \
  "${docker_options[@]}" \
  my-codex bash -c "
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

codex "${options[@]}"
"
