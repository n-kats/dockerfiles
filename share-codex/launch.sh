#!/bin/bash

this_script_dir="$(dirname "$(realpath "$0")")"
dockerfile_dir="${this_script_dir}/docker"
work_dir="$(pwd)"
image_name="share-codex"
codex_home=""
docker_options=()
options=()
build=0
skip=0
show_help=0
do_init=0
setup_script=""
config_file=""

for arg in "$@"; do
  if [ "$skip" -eq 1 ]; then
    skip=0
    shift
    continue
  fi
  case "$arg" in
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
    --config-file)
      config_file="$2"
      skip=1
      ;;
    --codex-home)
      codex_home="$2"
      skip=1
      ;;
    --init)
      do_init=1
      ;;
    --env-file)
      docker_options+=("--env-file" "$2")
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
      docker_options+=("-e" "OPENAI_API_KEY=${OPENAI_API_KEY:-}")
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

if [ ! -d "$work_dir" ]; then
  echo "[ERROR] Work directory does not exist: $work_dir"
  exit 1
fi

if [ "$do_init" -eq 1 ]; then
  local_dir="$work_dir/_local"
  homes_dir="$local_dir/codex_homes"
  templates_dir="$local_dir/templates"
  mkdir -p "$homes_dir" "$templates_dir"

  for file in codex.sh codex.toml setup.sh; do
    target="$local_dir/$file"
    if [ -e "$target" ]; then
      echo "[INFO] Skipping (already exists): $target"
    else
      cp "${this_script_dir}/samples/$file" "$target"
      echo "[INFO] Created: $target"
    fi
  done

  target="$templates_dir/template_AGENTS.md"
  if [ -e "$target" ]; then
    echo "[INFO] Skipping (already exists): $target"
  else
    cp "${this_script_dir}/samples/template_AGENTS.md" "$target"
    echo "[INFO] Created: $target"
  fi

  gitignore="$homes_dir/.gitignore"
  if [ -e "$gitignore" ]; then
    echo "[INFO] Skipping (already exists): $gitignore"
  else
    printf '*\n' > "$gitignore"
    echo "[INFO] Created: $gitignore"
  fi

  chmod +x "$local_dir/codex.sh" "$local_dir/setup.sh"
  exit 0
fi

codex_home="${codex_home:-_local/codex_homes}"
codex_home="$(realpath -m "$work_dir/$codex_home")"
mkdir -p "$codex_home"
chmod 700 "$codex_home" 2>/dev/null || true

if [ -z "$config_file" ]; then
  echo "[ERROR] --config-file is required"
  exit 1
fi
config_file="$(realpath -m "$work_dir/$config_file")"

if [ ! -f "$config_file" ]; then
  echo "[ERROR] Codex config not found: $config_file"
  exit 1
fi

if ! docker image inspect "$image_name" >/dev/null 2>&1; then
  build=1
fi

if [ "$build" -eq 1 ]; then
  set -e
  echo "[INFO] Building Docker image: $image_name"
  docker build \
    --build-arg TIMESTAMP="$(date +%Y%m%d_%H%M%S)" \
    -t "$image_name" "$dockerfile_dir"
fi

docker_options+=("-v" "$codex_home:/home/ubuntu/.codex")
docker_options+=("-v" "$config_file:/home/ubuntu/.codex/config.toml")
if [ -n "$setup_script" ]; then
  docker_options+=("-e" "SETUP_SCRIPT=$setup_script")
fi

if [ "$show_help" -eq 1 ]; then
  cat <<EOF
使い方: share-codex [--update] [--workdir <dir>] [--setup <script>] [--config-file <path>] [--codex-home <dir>] [-e <VAR=VAL>] [-v <SRC:DEST>] [その他のcodexオプション]

オプション:
  --update              Dockerイメージを更新して起動
  --workdir <dir>       対象ディレクトリ（デフォルトはカレントディレクトリ）
  --setup <script>      起動時に実行するセットアップスクリプト（対象ディレクトリからの相対パス）
  --config-file <path>  Codex設定ファイル（対象ディレクトリからの相対パス）
  --codex-home <dir>    Codexの設定・状態を置くディレクトリ（対象ディレクトリからの相対パス）
  --init                _local/ にサンプル設定と codex_homes/.gitignore を作成
  --env-file <path>     Dockerコンテナに環境ファイルを渡す
  -e, --env <VAR=VAL>   Dockerコンテナに環境変数を渡す
  -v, --volume <SRC:DEST> Dockerコンテナにボリュームをマウントする
  --api                 OPENAI_API_KEYをコンテナに渡す
  --help                このヘルプメッセージとcodexのヘルプを表示

相対パスは対象ディレクトリを基準に扱います。設定ファイルは Codex のホームに配置され、auth.json はアクセス拒否されます。
EOF
fi

docker_options+=("-it")

docker run --rm \
  --security-opt no-new-privileges:false \
  --security-opt seccomp=unconfined \
  --security-opt apparmor=unconfined \
  -u "$(id -u):$(id -g)" \
  -v "$work_dir:/workspace" \
  -w /workspace \
  --network host \
  -e "HOME=/home/ubuntu" \
  -e "TERM=${TERM:-xterm-256color}" \
  -e "COLORTERM=${COLORTERM:-}" \
  "${docker_options[@]}" \
  "$image_name" bash -c '
umask 000
home_dir="${HOME:-/home/ubuntu}"
chmod 710 "$home_dir" 2>/dev/null || true
chmod 700 "$home_dir/.codex" 2>/dev/null || true

if [ -n "${SETUP_SCRIPT:-}" ]; then
  if [ -f "$SETUP_SCRIPT" ]; then
    echo "[INFO] Running setup script: $SETUP_SCRIPT" >&2
    source "$SETUP_SCRIPT"
  else
    echo "[ERROR] Setup script not found: $SETUP_SCRIPT" >&2
    exit 1
  fi
fi

codex "$@"
' bash "${options[@]}"
