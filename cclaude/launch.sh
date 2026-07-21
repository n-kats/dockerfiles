#!/bin/bash

this_script_dir="$(dirname "$(realpath "$0")")"
dockerfile_dir="${this_script_dir}/docker"
work_dir="$(pwd)"
image_name="cclaude-cli"
build=0
skip=0
show_help=0
show_init_help=0
do_init=0
LITELLM_URL=""
litellm_url_set=0
setup_script=""
claude_json=""
host_gitconfig=""
docker_options=()
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
    --litellm-url)
      LITELLM_URL="$2"
      litellm_url_set=1
      skip=1
      ;;
    --env-file)
      docker_options+=("--env-file" "$2")
      skip=1
      ;;
    --claude-json)
      claude_json="$2"
      skip=1
      ;;
    --gitconfig)
      host_gitconfig="$(realpath -m "$2")"
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
  echo "[_local/claude.env, 秘密ファイル]"
  echo "- シンボリックリンクパターン: ln -s path/to/other/claude.env _local/claude.env"
  echo ""
  echo "[_local/claude.sh]"
  cat "${samples_dir}/claude.sh"
  echo ""
  echo "[_local/claude.json]"
  cat "${samples_dir}/claude.json"
  echo ""
  echo "[.claude/settings.json]"
  cat "${samples_dir}/settings.json"
  echo ""
  echo "[_local/setup_claude.sh]"
  cat "${samples_dir}/setup_claude.sh"
  exit 0
fi

if [ "$do_init" -eq 1 ]; then
  samples_dir="${this_script_dir}/samples"
  local_dir="${work_dir}/_local"
  settings_dir="${work_dir}/.claude"

  if [ ! -d "$work_dir" ]; then
    echo "[ERROR] 作業ディレクトリが存在しません: $work_dir"
    exit 1
  fi

  relpath_in_workdir() {
    local path="$1"
    if [[ "$path" == "$work_dir" ]]; then
      echo "."
      return
    fi
    if [[ "$path" == "$work_dir/"* ]]; then
      echo "${path#$work_dir/}"
      return
    fi
    echo "$path"
  }

  open_diff_editor() {
    local left="$1"
    local right="$2"
    local editor_cmd=()

    if [ -z "${EDITOR:-}" ]; then
      echo "[ERROR] 差分がある既存ファイルを開くには EDITOR が必要です"
      echo "[INFO] 例: export EDITOR=vim"
      exit 1
    fi

    IFS=' ' read -r -a editor_cmd <<< "$EDITOR"
    if [ "${#editor_cmd[@]}" -eq 0 ]; then
      echo "[ERROR] EDITOR が空です"
      exit 1
    fi
    if ! command -v "${editor_cmd[0]}" >/dev/null 2>&1; then
      echo "[ERROR] EDITOR のコマンドが見つかりません: ${editor_cmd[0]}"
      exit 1
    fi

    echo "[INFO] 差分確認: $(relpath_in_workdir "$right")"
    "${editor_cmd[@]}" -d "$left" "$right"
  }

  echo "[INFO] 初期化: $(relpath_in_workdir "$local_dir")"
  mkdir -p "$local_dir"

  for file in claude.sh claude.json setup_claude.sh; do
    src="${samples_dir}/${file}"
    dst="${local_dir}/${file}"
    if [ -e "$dst" ]; then
      if cmp -s "$src" "$dst"; then
        echo "[INFO] スキップ（既存）: $(relpath_in_workdir "$dst")"
        continue
      fi
      open_diff_editor "$src" "$dst"
      echo "[INFO] 更新: $(relpath_in_workdir "$dst")"
      continue
    fi
    cp "$src" "$dst"
    echo "[INFO] 作成: $(relpath_in_workdir "$dst")"
  done

  src="${samples_dir}/settings.json"
  dst="${settings_dir}/settings.json"
  mkdir -p "$settings_dir"
  if [ -e "$dst" ]; then
    if cmp -s "$src" "$dst"; then
      echo "[INFO] スキップ（既存）: $(relpath_in_workdir "$dst")"
    else
      open_diff_editor "$src" "$dst"
      echo "[INFO] 更新: $(relpath_in_workdir "$dst")"
    fi
  else
    cp "$src" "$dst"
    echo "[INFO] 作成: $(relpath_in_workdir "$dst")"
  fi

  chmod +x "${local_dir}/claude.sh" "${local_dir}/setup_claude.sh" 2>/dev/null || true
  exit 0
fi

if [ -z "$CLAUDE_CACHE_DIR" ]; then
  echo "[ERROR] CLAUDE_CACHE_DIR が設定されていません"
  exit 1
fi

cache_dir="$(realpath -m "$CLAUDE_CACHE_DIR")"
mkdir -p "$cache_dir"
if [ ! -d "$cache_dir" ]; then
  echo "[ERROR] CLAUDE_CACHE_DIR がディレクトリではありません: $cache_dir"
  exit 1
fi

if [ ! -d "$work_dir" ]; then
  echo "[ERROR] 作業ディレクトリが存在しません: $work_dir"
  exit 1
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
    echo "[INFO] ディレクトリを作成: $claude_json_dir"
    mkdir -p "$claude_json_dir"
  fi
  if [ ! -f "$claude_json" ]; then
    echo "[INFO] ファイルを作成: $claude_json"
    printf '%s\n' '{}' > "$claude_json"
  fi
fi

# Build image automatically if it does not exist
if ! docker image inspect "$image_name" >/dev/null 2>&1; then
  build=1
fi

if [ "$build" -eq 1 ]; then
  (
    set -e
    echo "[INFO] Dockerイメージをビルド"
    docker build --build-arg TIMESTAMP=$(date +%Y%m%d_%H%M%S) -t "$image_name" "$dockerfile_dir"
  )
fi

if [ -n "$host_gitconfig" ]; then
  if [ ! -f "$host_gitconfig" ]; then
    echo "[ERROR] gitconfig が見つかりません: $host_gitconfig"
    exit 1
  fi
  docker_options+=("-v" "$host_gitconfig:/tmp/host_gitconfig:ro")
  docker_options+=("-e" "CCLAUDE_HOST_GITCONFIG=/tmp/host_gitconfig")
fi

if [ -n "$input_tmpfile" ]; then
  docker_options+=("-v" "$input_tmpfile:/tmp/claude_stdin:ro")
fi

docker_options+=("-e" "HOME=/home/ubuntu")

mount_dir="$cache_dir/mount/user/ubuntu"

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
    echo "[INFO] ディレクトリを作成: $full_path"
    mkdir -p "$full_path"
  fi
  docker_options+=("-v" "$full_path:/home/ubuntu/$path")
done
docker_options+=("-v" "$claude_json:/home/ubuntu/.claude.json")

if [ "$show_help" -eq 1 ]; then
  cat << EOF
使い方: cclaude [--update] [--workdir <dir>] [--setup <script>] [--litellm-url <url>] [--env-file <file>] [--claude-json <file>] [--gitconfig <path>] [-e <VAR=VAL>] [-v <SRC:DEST>] [その他のclaudeオプション]

オプション:
  --update              Claude CLI のDockerイメージを更新して起動
  --workdir <dir>       対象ディレクトリ（デフォルトはカレントディレクトリ）
  --setup <script>      起動時に実行するセットアップスクリプト
  --litellm-url <url>   LiteLLM のベースURL（指定時のみLiteLLM経由にする）
  --env-file <file>     Dockerコンテナに環境変数を渡す
  --claude-json <file>  claude.json を指定してマウントする
  --gitconfig <path>    ホストの gitconfig を /tmp/host_gitconfig に読み取り専用でマウント（コンテナ側のglobal設定からinclude）
  -e, --env <VAR=VAL>   Dockerコンテナに環境変数を渡す
  -v, --volume <SRC:DEST> Dockerコンテナにボリュームをマウントする
  --init                _local/ と .claude/ に設定ファイルを作成（同一ならスキップ、差分は \$EDITOR -d で確認）
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

docker_options+=("-e" "NO_COLOR=1")
docker_options+=("-e" "FORCE_COLOR=0")
docker_options+=("-e" "DISABLE_AUTOUPDATER=1")
docker_options+=("-e" "GIT_OPTIONAL_LOCKS=0")
docker_options+=("-e" "CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1")

command_str="claude ${options[@]}"

docker run --rm \
  -u "$(id -u):$(id -g)" \
  -v "$work_dir:/workspace" \
  -e "TERM=${TERM:-xterm-256color}" \
  -e "COLORTERM=${COLORTERM:-}" \
  -w "/workspace" \
  --network host \
  --security-opt no-new-privileges:false \
  --security-opt seccomp=unconfined \
  --security-opt apparmor=unconfined \
  --cap-add NET_ADMIN \
  "${docker_options[@]}" \
  "$image_name" bash -c "
umask 000
export GIT_CONFIG_GLOBAL=\"/home/ubuntu/.config/git/config\"
mkdir -p \"\$(dirname \"\$GIT_CONFIG_GLOBAL\")\"
touch \"\$GIT_CONFIG_GLOBAL\"

if [ -n \"\$CCLAUDE_HOST_GITCONFIG\" ]; then
  if ! rg -Fq \"path = \$CCLAUDE_HOST_GITCONFIG\" \"\$GIT_CONFIG_GLOBAL\"; then
    printf '\\n[include]\\n  path = %s\\n' \"\$CCLAUDE_HOST_GITCONFIG\" >>\"\$GIT_CONFIG_GLOBAL\"
  fi
fi

if [ -n \"$setup_script\" ]; then
  if [ -f \"$setup_script\" ]; then
    echo \"[INFO] セットアップスクリプトを実行: $setup_script\" 1>&2
    source \"$setup_script\" 1>&2
  else
    echo \"[ERROR] セットアップスクリプトが見つかりません: $setup_script\" 1>&2
    exit 1
  fi
fi

if [ -n \"$input_tmpfile\" ]; then
  cat /tmp/claude_stdin | ${command_str}
else
  ${command_str}
fi
"
