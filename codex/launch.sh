#!/bin/bash

if [ -z "$CODEX_CACHE_DIR" ]; then
  echo "CODEX_CACHE_DIR is not set"
  exit 1
fi

this_script_dir="$(dirname "$(realpath "$0")")"
dockerfile_dir="${this_script_dir}/docker"
cache_dir="$(realpath "$CODEX_CACHE_DIR")"
work_dir="$(pwd)"
image_name="my-codex"
docker_options=()
build=0
skip=0
use_api_key=0
show_help=0
host_gitconfig=""
host_codex_bin=""
codex_homes_dir=""
setup_script=""
input_tmpfile=""

if [ ! -t 0 ]; then
  input_tmpfile="$(mktemp)"
  docker_options+=("-v" "$input_tmpfile:/tmp/codex_stdin:ro")
  cat - > "$input_tmpfile"
fi

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
    --codex-homes-dir)
      codex_homes_dir="$(realpath -m "$2")"
      skip=1
      ;;
    --env-file)
      docker_options+=("--env-file" "$2")
      skip=1
      ;;
    --gitconfig)
      host_gitconfig="$(realpath -m "$2")"
      skip=1
      ;;
    --bin)
      host_codex_bin="$(realpath -m "$2")"
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

if [ ! -d "$work_dir" ]; then
  echo "[ERROR] Work directory does not exist: $work_dir"
  exit 1
fi

# Build image automatically if it does not exist
if ! docker image inspect "$image_name" >/dev/null 2>&1; then
  build=1
fi

if [ "$build" -eq 1 ]; then
  set -e
  (
    echo "[INFO] Building Docker image"
    docker build --build-arg TIMESTAMP=$(date +%Y%m%d_%H%M%S) -t "$image_name" "$dockerfile_dir"
  )
fi

if [ "$use_api_key" -eq 1 ]; then
  if [ -n "$codex_homes_dir" ]; then
    codex_dir_name="codex_with_api"
  else
    codex_dir_name="codex_with_api_key"
  fi
  mount_cache_dir="cache_with_api_key"
  mount_local_dir="local_with_api_key"
  docker_options+=("-e" "OPENAI_API_KEY=$OPENAI_API_KEY")
else
  codex_dir_name="codex"
  mount_cache_dir="cache"
  mount_local_dir="local"
fi

user=ubuntu
mount_dir="$cache_dir/mount/user/$user"
for dir in \
  $mount_cache_dir:.cache \
  $mount_local_dir:.local \
  config:.config \
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
  chmod 0777 "$full_path" 2>/dev/null || true
  docker_options+=("-v" "$full_path:/home/$user/$path")
done

if [ -n "$host_gitconfig" ]; then
  if [ ! -f "$host_gitconfig" ]; then
    echo "[ERROR] gitconfig not found: $host_gitconfig"
    exit 1
  fi
  docker_options+=("-v" "$host_gitconfig:/tmp/host_gitconfig:ro")
  docker_options+=("-e" "CODEX_HOST_GITCONFIG=/tmp/host_gitconfig")
fi

if [ -n "$host_codex_bin" ]; then
  if [ ! -f "$host_codex_bin" ]; then
    echo "[ERROR] codex バイナリが見つかりません: $host_codex_bin"
    exit 1
  fi
  if [ ! -x "$host_codex_bin" ]; then
    echo "[ERROR] codex バイナリが実行可能ではありません: $host_codex_bin"
    exit 1
  fi
  docker_options+=("-v" "$host_codex_bin:/usr/local/bin/codex:ro")
  docker_options+=("-e" "CODEX_HOST_CODEX_BIN=/usr/local/bin/codex")
fi

if [ -n "$codex_homes_dir" ]; then
  codex_home_host_dir="$codex_homes_dir/$codex_dir_name"
else
  codex_home_host_dir="$cache_dir/mount/user/$codex_dir_name"
fi
if [ ! -d "$codex_home_host_dir" ]; then
  echo "[INFO] Creating directory: $codex_home_host_dir"
  mkdir -p "$codex_home_host_dir"
fi
chmod 0700 "$codex_home_host_dir" 2>/dev/null || true
docker_options+=("-v" "$codex_home_host_dir:/home/ubuntu/.codex")

if [ "$show_help" -eq 1 ]; then
  cat << EOF
使い方: codex [--update] [--workdir <dir>] [--setup <script>] [--codex-homes-dir <dir>] [--gitconfig <path>] [--bin <path>] [-e <VAR=VAL>] [-v <SRC:DEST>] [その他のcodexオプション]

オプション:
  --update              codexを更新して起動
  --workdir <dir>       対象ディレクトリ（デフォルトはカレントディレクトリ）
  --setup <script>      起動時に実行するセットアップスクリプト
  --codex-homes-dir <dir> ~/.codex を <dir>/{codex,codex_with_api} からマウント
  --gitconfig <path>    ホストの gitconfig を /tmp/host_gitconfig に読み取り専用でマウント（ubuntu側のglobal設定からinclude）
  --bin <path>          ホストの codex バイナリを /usr/local/bin/codex に読み取り専用でマウントして使用
  -e, --env <VAR=VAL>   Dockerコンテナに環境変数を渡す
  -v, --volume <SRC:DEST> Dockerコンテナにボリュームをマウントする
  --api                 OpenAI APIキーを使用（環境変数OPENAI_API_KEYが必要）
  --help                このヘルプメッセージとcodexのヘルプを表示
EOF
fi

command_str="codex ${options[@]}"

if [ "$input_tmpfile" != "" ]; then
  docker_options+=("-i")
else
  docker_options+=("-it")
fi

docker run --rm \
  --security-opt no-new-privileges:false \
  -u "$(id -u):$(id -g)" \
  -v "$work_dir:/workspace" \
  --security-opt seccomp=unconfined \
  --security-opt apparmor=unconfined \
  -e "TERM=${TERM:-xterm-256color}" \
  -e "COLORTERM=${COLORTERM:-}" \
  -w "/workspace" \
  --network host \
  "${docker_options[@]}" \
  "$image_name" bash -c "
umask 000
home_dir_in_docker=\"\$(getent passwd \"\$(id -u)\" 2>/dev/null | cut -d: -f6)\"
if [ -z \"\$home_dir_in_docker\" ]; then
  home_dir_in_docker=\"\${HOME:-/home/ubuntu}\"
fi
if [ -z \"\$home_dir_in_docker\" ]; then
  home_dir_in_docker=/home/ubuntu
fi
chmod 710 \"\$home_dir_in_docker\" 2>/dev/null || true
chmod 700 \"\$home_dir_in_docker/.codex\" 2>/dev/null || true

export GIT_CONFIG_GLOBAL=\"\$home_dir_in_docker/.config/git/config\"
mkdir -p \"\$(dirname \"\$GIT_CONFIG_GLOBAL\")\"
touch \"\$GIT_CONFIG_GLOBAL\"
chmod a+rw \"\$GIT_CONFIG_GLOBAL\" 2>/dev/null || true

if [ -n \"\$CODEX_HOST_GITCONFIG\" ]; then
  if ! rg -Fq \"path = \$CODEX_HOST_GITCONFIG\" \"\$GIT_CONFIG_GLOBAL\"; then
    printf '\\n[include]\\n  path = %s\\n' \"\$CODEX_HOST_GITCONFIG\" >>\"\$GIT_CONFIG_GLOBAL\"
  fi
fi

if [ -n \"\$CODEX_HOST_CODEX_BIN\" ]; then
  if [ -x \"\$CODEX_HOST_CODEX_BIN\" ]; then
    echo \"[INFO] ホストの codex バイナリを使用します: \$CODEX_HOST_CODEX_BIN\" 1>&2
    if command -v getcap >/dev/null 2>&1; then
      if [ -z \"\$(getcap \"\$CODEX_HOST_CODEX_BIN\" 2>/dev/null)\" ]; then
        echo \"[NOTE] ホストの codex バイナリに file capabilities (setcap) が付いていません。サンドボックス関連の機能が失敗する場合は、例: sudo setcap 'cap_setuid,cap_setgid=ep' <path-to-codex>\" 1>&2
      fi
    fi
  else
    echo \"[ERROR] CODEX_HOST_CODEX_BIN が設定されていますが実行できません: \$CODEX_HOST_CODEX_BIN\" 1>&2
    exit 1
  fi
fi

if [ -n \"$setup_script\" ]; then
  if [ -f \"$setup_script\" ]; then
    echo \"[INFO] Running setup script: $setup_script\" 1>&2
    source \"$setup_script\" 1>&2
  else
    echo \"[ERROR] Setup script not found: $setup_script\" 1>&2
    exit 1
  fi
fi

alias apply_patch=patch
if [ -n \"$input_tmpfile\" ]; then
  cat /tmp/codex_stdin | ${command_str}
else
  ${command_str}
fi
"
