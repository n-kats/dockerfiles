#!/bin/bash

this_script_dir="$(dirname "$(realpath "$0")")"
dockerfile_dir="${this_script_dir}/docker"
image_name="lite-llm"
container_name="lite-llm"
port="4000"
port_override=0
host=""
config_file=""
profile_file=""
mode="start"
build=0
skip=0
show_help=0
do_init=0
env_file=""
envs=()

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
    --name)
      container_name="${2:?--name には値が必要です。}"
      skip=1
      ;;
    --port)
      port="${2:?--port には値が必要です。}"
      port_override=1
      skip=1
      ;;
    --config)
      config_file="$(realpath -m "${2:?--config には値が必要です。}")"
      skip=1
      ;;
    --env-file)
      env_file="${2:?--env-file には値が必要です。}"
      skip=1
      ;;
    -e|--env)
      envs+=("$2")
      skip=1
      ;;
    --init)
      do_init=1
      ;;
    edit-config)
      mode="edit_config"
      ;;
    edit-profile)
      mode="edit_profile"
      ;;
    get-url)
      mode="get_url"
      ;;
    down|stop)
      mode="down"
      ;;
    logs)
      mode="logs"
      ;;
    --help)
      show_help=1
      ;;
    *)
      ;;
  esac
  shift
done

if [ -z "$config_file" ]; then
  config_file="$HOME/.config/dockerfiles/lite-llm/${container_name}.yaml"
fi
if [ -z "$profile_file" ]; then
  profile_file="$HOME/.config/dockerfiles/lite-llm/${container_name}.profile.json"
fi

if [ "$show_help" -eq 1 ]; then
  cat << EOF
使い方: lite-llm [--update] [--name <name>] [--port <port>] [--config <file>] [--env-file <file>] [-e <VAR=VAL>] [--init] [edit-config|edit-profile|get-url|down|logs]

オプション:
  --update              LiteLLM のDockerイメージを更新して起動
  --name <name>         コンテナ名（デフォルトは lite-llm）
  --port <port>         ホスト側の公開ポート（デフォルトは 4000）
  --config <file>       設定ファイル（デフォルトは ~/.config/dockerfiles/lite-llm/<name>.yaml）
  --env-file <file>     Dockerコンテナに環境変数を渡す
  -e, --env <VAR=VAL>   Dockerコンテナに環境変数を渡す
  --init                設定ファイルとプロファイルを作成（既存はスキップ）
  edit-config           \$EDITOR で設定ファイルを開く
  edit-profile          \$EDITOR でプロファイル(JSON)を開く
  get-url               接続URLを出力
  down, stop            コンテナを停止して削除
  logs                  ログを表示

プロファイル:
  ~/.config/dockerfiles/lite-llm/<name>.profile.json
  {"port":4000,"host":"localhost","mount":["/host/path:/container/path:ro"],"env_map":[{"from":"A","to":"B"}],"env_files":["/path/to/.env"]}
EOF
  exit 0
fi

if [ "$do_init" -eq 1 ]; then
  config_file="$(realpath -m "$config_file")"
  profile_file="$(realpath -m "$profile_file")"
  config_dir="$(dirname "$config_file")"
  profile_dir="$(dirname "$profile_file")"
  sample_file="${this_script_dir}/samples/config.yaml"

  if ! command -v jq >/dev/null 2>&1; then
    echo "[ERROR] --init には jq が必要です"
    exit 1
  fi

  if [ ! -f "$sample_file" ]; then
    echo "[ERROR] サンプル設定ファイルが見つかりません: $sample_file"
    exit 1
  fi

  mkdir -p "$config_dir" "$profile_dir"
  if [ -e "$config_file" ]; then
    echo "[INFO] Skipping (already exists): $config_file"
  else
    cp "$sample_file" "$config_file"
    echo "[INFO] Created: $config_file"
  fi

  if [ -e "$profile_file" ]; then
    echo "[INFO] Skipping (already exists): $profile_file"
    exit 0
  fi

  read -r -p "ポート番号（デフォルト: 4000）: " input_port
  if [ -z "$input_port" ]; then
    input_port="4000"
  fi

  read -r -p "ホスト（デフォルト: localhost）: " input_host
  if [ -z "$input_host" ]; then
    input_host="localhost"
  fi

  echo "マウント指定（1行1つ、空行で終了）:"
  echo "  書式: /host/absolute/path:/container/path[:ro|rw]"
  echo "  注意: ホスト側は絶対パス推奨（相対パスはボリューム名扱いになりやすい）"
  echo "        \$HOME や ~ などの変数/展開は使えません（そのまま文字列として渡されます）"
  echo "  例  : /home/user/.config:/home/user/.config:ro"
  echo "        /path/on/host:/path/in/container"
  mount_lines=()
  while IFS= read -r line; do
    if [ -z "$line" ]; then
      break
    fi
    mount_lines+=("$line")
  done

  mount_json="$(printf '%s\n' "${mount_lines[@]}" | jq -Rsc 'split("\n") | map(select(length>0))')"
  if [[ "$input_port" =~ ^[0-9]+$ ]]; then
    port_value="$input_port"
  else
    port_value="4000"
  fi
  jq -n \
    --arg host "$input_host" \
    --argjson port "$port_value" \
    --argjson mounts "$mount_json" \
    '{
      port:$port,
      host:$host,
      mount:$mounts,
      env_map:[
        {"from":"OPENAI_API_KEY","to":"OPENAI_API_KEY"}
      ],
      env_files:[]
    }' > "$profile_file"
  echo "" >> "$profile_file"
  echo "[INFO] Created: $profile_file"
  exit 0
fi

if [ "$mode" = "down" ]; then
  existing_name="$(docker ps -a --filter "name=^/${container_name}$" --format '{{.Names}}' | head -n 1)"
  if [ "$existing_name" = "$container_name" ]; then
    docker rm -f "$container_name"
    echo "[INFO] Stopped: $container_name"
  else
    echo "[INFO] Not found: $container_name"
  fi
  exit 0
fi

if [ "$mode" = "logs" ]; then
  docker logs -f "$container_name"
  exit $?
fi

config_file="$(realpath -m "$config_file")"
profile_file="$(realpath -m "$profile_file")"

if [ "$mode" = "get_url" ]; then
  if [ "$port_override" -ne 1 ] && [ -r "$profile_file" ] && command -v jq >/dev/null 2>&1; then
    profile_port="$(jq -r '.port // empty' "$profile_file" 2>/dev/null || true)"
    if [[ "$profile_port" =~ ^[0-9]+$ ]]; then
      port="$profile_port"
    fi
  fi
  if [ -r "$profile_file" ] && command -v jq >/dev/null 2>&1; then
    profile_host="$(jq -r '.host // empty' "$profile_file" 2>/dev/null || true)"
    if [ -n "$profile_host" ]; then
      host="$profile_host"
    fi
  fi

  if [ -z "$host" ] || [ "$host" = "localhost" ]; then
    host="127.0.0.1"
  fi

  echo "http://${host}:${port}"
  exit 0
fi

if [ "$mode" = "edit_config" ] || [ "$mode" = "edit_profile" ]; then
  if [ -z "${EDITOR:-}" ]; then
    echo "[ERROR] EDITOR が設定されていません"
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

  if [ "$mode" = "edit_config" ]; then
    if [ ! -f "$config_file" ]; then
      echo "[ERROR] LiteLLM 設定ファイルが見つかりません: $config_file"
      echo "[INFO] 対処: lite-llm --init --name $container_name"
      exit 1
    fi
    "${editor_cmd[@]}" "$config_file"
    exit $?
  fi

  if [ ! -f "$profile_file" ]; then
    echo "[ERROR] LiteLLM プロファイルが見つかりません: $profile_file"
    echo "[INFO] 対処: lite-llm --init --name $container_name"
    exit 1
  fi
  "${editor_cmd[@]}" "$profile_file"
  exit $?
fi

if [ ! -f "$config_file" ]; then
  echo "[ERROR] LiteLLM 設定ファイルが見つかりません: $config_file"
  echo "[INFO] 対処: lite-llm --init --name $container_name"
  exit 1
fi

if [ ! -f "$profile_file" ]; then
  echo "[ERROR] LiteLLM プロファイルが見つかりません: $profile_file"
  echo "[INFO] 対処: lite-llm --init --name $container_name"
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

profile_port=""
profile_host=""
profile_mounts=()

if [ ! -r "$profile_file" ]; then
  echo "[ERROR] LiteLLM プロファイルを読み取れません: $profile_file"
  echo "[INFO] 所有者/権限の確認: ls -la \"$profile_file\""
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "[ERROR] プロファイルの読み取りには jq が必要です: $profile_file"
  exit 1
fi

if ! jq -e '
    (type == "object")
    and (has("port") and (.port | type == "number"))
    and (has("host") and (.host | type == "string"))
    and ((has("mount") | not) or (.mount | type == "array"))
    and (
      (has("env_map") | not)
      or (
        (.env_map | type == "array")
        and all(
          .env_map[];
          (type == "object")
          and (has("from") and (.from | type == "string"))
          and (has("to") and (.to | type == "string"))
          and ((has("required") | not) or (.required | type == "boolean"))
          and ((has("default") | not) or (.default | type == "string"))
        )
      )
    )
    and (
      (has("env_files") | not)
      or (
        (.env_files | type == "array")
        and all(.env_files[]; type == "string")
      )
    )
  ' "$profile_file" >/dev/null; then
  echo "[ERROR] LiteLLM プロファイル JSON が不正です: $profile_file"
  exit 1
fi

profile_port="$(jq -r '.port' "$profile_file")"
profile_host="$(jq -r '.host' "$profile_file")"
profile_mount_lines="$(jq -r '(.mount // [])[]' "$profile_file")"
profile_env_file_lines="$(jq -r '(.env_files // [])[]' "$profile_file")"
profile_env_map_lines="$(jq -r '(.env_map // [])[] | [.from,.to,(.required // false | tostring),(.default // "")] | @tsv' "$profile_file")"

if [ -n "$profile_mount_lines" ]; then
  while IFS= read -r line; do
    if [ -n "$line" ]; then
      profile_mounts+=("$line")
    fi
  done <<< "$profile_mount_lines"
fi

profile_env_files=()
if [ -n "$profile_env_file_lines" ]; then
  while IFS= read -r line; do
    if [ -n "$line" ]; then
      profile_env_files+=("$line")
    fi
  done <<< "$profile_env_file_lines"
fi

profile_envs=()
if [ -n "$profile_env_map_lines" ]; then
  while IFS=$'\t' read -r from_var to_var required default_value; do
    if [ -z "$from_var" ] || [ -z "$to_var" ]; then
      continue
    fi
    value="${!from_var-}"
    if [ -z "$value" ] && [ -n "$default_value" ]; then
      value="$default_value"
    fi
    if [ -z "$value" ] && [ "$required" = "true" ]; then
      echo "[ERROR] 必須の環境変数が設定されていません: $from_var（→ $to_var）"
      exit 1
    fi
    if [ -n "$value" ]; then
      profile_envs+=("-e" "${to_var}=${value}")
    fi
  done <<< "$profile_env_map_lines"
fi

if [ "$port_override" -ne 1 ] && [ -n "$profile_port" ]; then
  port="$profile_port"
fi

if [ -n "$profile_host" ]; then
  host="$profile_host"
fi

if [ -z "$host" ]; then
  host="127.0.0.1"
elif [ "$host" = "localhost" ]; then
  host="127.0.0.1"
fi

# Build image automatically if it does not exist
if ! docker image inspect "$image_name" >/dev/null 2>&1; then
  build=1
fi

if [ "$build" -eq 1 ]; then
  (
    set -e
    echo "[INFO] Building LiteLLM Docker image"
    docker build -t "$image_name" "$dockerfile_dir"
  )
fi

running_name="$(docker ps --filter "name=^/${container_name}$" --format '{{.Names}}' | head -n 1)"
if [ "$running_name" = "$container_name" ]; then
  echo "[INFO] Already running: $container_name"
  exit 0
fi

existing_name="$(docker ps -a --filter "name=^/${container_name}$" --format '{{.Names}}' | head -n 1)"
if [ "$existing_name" = "$container_name" ]; then
  docker rm -f "$container_name" >/dev/null 2>&1 || true
fi

container_envs=()
if [ -n "${LITELLM_MASTER_KEY:-}" ]; then
  container_envs+=("-e" "LITELLM_MASTER_KEY=$LITELLM_MASTER_KEY")
fi

for profile_env_file in "${profile_env_files[@]}"; do
  expanded="$profile_env_file"
  if [[ "$expanded" == "~/"* ]]; then
    expanded="$HOME/${expanded#~/}"
  fi
  expanded="$(realpath -m "$expanded")"
  if [ ! -f "$expanded" ]; then
    echo "[ERROR] Envファイルが見つかりません（プロファイル指定）: $expanded"
    exit 1
  fi
  container_envs+=("--env-file" "$expanded")
done

if [ -n "$env_file" ]; then
  container_envs+=("--env-file" "$env_file")
fi

for env_kv in "${profile_envs[@]}"; do
  container_envs+=("$env_kv")
done

for env in "${envs[@]}"; do
  container_envs+=("-e" "$env")
done

mount_options=()
for mount in "${profile_mounts[@]}"; do
  mount_options+=("-v" "$mount")
done

docker run -d \
  --name "$container_name" \
  --restart unless-stopped \
  -p "${host}:${port}:4000" \
  -v "$config_file:/config/config.yaml:ro" \
  "${mount_options[@]}" \
  "${container_envs[@]}" \
  "$image_name" \
  --config /config/config.yaml \
  --host 0.0.0.0 \
  --port 4000 \
  >/dev/null

echo "[INFO] Started: $container_name (${host}:${port})"
