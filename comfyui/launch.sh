#!/bin/bash

if [ -z "$COMFYUI_CACHE_DIR" ]; then
  echo "[ERROR] COMFYUI_CACHE_DIR is not set"
  exit 1
fi

this_script_dir="$(dirname "$(realpath "$0")")"
dockerfile_dir="${this_script_dir}/docker"
cache_dir="$(realpath -m "$COMFYUI_CACHE_DIR")"
container_name="comfyui"
image_name="my-comfyui"
build=0
skip=0
show_help=0
docker_options=()
subcommand=""
sub_args=()

host_comfyui="${COMFYUI_HOST:-}"
host_port="${COMFYUI_PORT:-18188}"

mkdir -p "$cache_dir"
if [ ! -d "$cache_dir" ]; then
  echo "[ERROR] COMFYUI_CACHE_DIR is not a directory: $cache_dir"
  exit 1
fi

for arg in "$@"; do
  if [ -n "$subcommand" ]; then
    sub_args+=("$arg")
    continue
  fi
  if [ "$skip" -eq 1 ]; then
    skip=0
    shift
    continue
  fi
  case "$arg" in
    --update)
      build=1
      ;;
    -e|--env)
      docker_options+=("-e" "$2")
      skip=1
      ;;
    -v|--volume)
      docker_options+=("-v" "$2")
      skip=1
      ;;
    --help|-h|help)
      show_help=1
      ;;
    down|logs|exec|download)
      subcommand="$arg"
      ;;
    *)
      echo "[ERROR] 存在しないオプションです: $arg"
      echo "[INFO] 'comfyui --help' で使い方を確認してください"
      exit 1
      ;;
  esac
  shift
done

if ! docker image inspect "$image_name" >/dev/null 2>&1; then
  build=1
fi

if [ "$build" -eq 1 ]; then
  set -e
  echo "[INFO] Building Docker image"
  docker build --build-arg TIMESTAMP="$(date +%Y%m%d_%H%M%S)" -t "$image_name" "$dockerfile_dir"
fi

mount_dir="$cache_dir/mount/user/ubuntu"
home_dir_in_docker="/home/ubuntu/ComfyUI"

for dir in \
  comfyui_models:models \
  comfyui_input:input \
  comfyui_output:output \
  comfyui_user:user \
  comfyui_custom_nodes:custom_nodes \
; do
  IFS=":" read -r name path <<< "$dir"
  full_path="$mount_dir/$name"
  if [ ! -d "$full_path" ]; then
    echo "[INFO] Creating directory: $full_path"
    mkdir -p "$full_path"
  fi
  docker_options+=("-v" "$full_path:$home_dir_in_docker/$path")
done

docker_options+=("-e" "HOME=/tmp/comfyui-home")
docker_options+=("-e" "USER=ubuntu")
docker_options+=("-e" "LOGNAME=ubuntu")

function container_exists() {
  [[ -n "$(docker ps -aq --filter "name=^/${container_name}$")" ]]
}

function container_running() {
  [[ -n "$(docker ps -q --filter "name=^/${container_name}$")" ]]
}

function show_help() {
  cat << EOF
使い方: comfyui [--update] [-e <VAR=VAL>] [-v <SRC:DEST>] [help|down|logs|exec|download]

オプション:
  --update               ComfyUIイメージを再ビルドして起動
  -e, --env <VAR=VAL>    Dockerコンテナに環境変数を渡す
  -v, --volume <SRC:DEST> Dockerコンテナにボリュームをマウントする
  --help                 このヘルプメッセージを表示

サブコマンド:
  down                   comfyuiコンテナを停止する
  logs                   ログを表示する
  exec [cmd...]          コンテナ内でコマンドを実行する（未指定なら bash）
  download <url> <dir>   URLからモデルを指定ディレクトリにダウンロードする

環境変数:
  COMFYUI_HOST           Dockerの公開先ホストIP（未指定なら全インターフェース）
  COMFYUI_PORT           ホスト側の公開ポート（デフォルト: 18188）

保存先:
  $cache_dir/mount/user/ubuntu/comfyui_models/<dir>
  $cache_dir/mount/user/ubuntu/comfyui_models     -> /home/ubuntu/ComfyUI/models
  $cache_dir/mount/user/ubuntu/comfyui_input      -> /home/ubuntu/ComfyUI/input
  $cache_dir/mount/user/ubuntu/comfyui_output     -> /home/ubuntu/ComfyUI/output
  $cache_dir/mount/user/ubuntu/comfyui_user       -> /home/ubuntu/ComfyUI/user
  $cache_dir/mount/user/ubuntu/comfyui_custom_nodes -> /home/ubuntu/ComfyUI/custom_nodes
EOF
}

if [ "$show_help" -eq 1 ]; then
  show_help
  exit 0
fi

function download_model() {
  if [ "$#" -lt 2 ]; then
    echo "[ERROR] download には URL と保存先ディレクトリが必要です"
    echo "[INFO] 使い方: comfyui download <url> <dir>"
    exit 1
  fi

  url="$1"
  target_dir="$2"
  case "$target_dir" in
    ""|.|..|*/*|*..*)
      echo "[ERROR] ディレクトリ名に使用できない文字が含まれています: $target_dir"
      exit 1
      ;;
  esac
  if printf '%s' "$target_dir" | grep -q '\'; then
    echo "[ERROR] ディレクトリ名に使用できない文字が含まれています: $target_dir"
    exit 1
  fi

  download_dir="$mount_dir/comfyui_models/$target_dir"
  mkdir -p "$download_dir"

  filename="$(basename "${url%%\?*}")"
  if [ -z "$filename" ] || [ "$filename" = "/" ] || [ "$filename" = "." ]; then
    filename="downloaded_model"
  fi

  destination="$download_dir/$filename"
  tmp_destination="${destination}.part"

  if [ -e "$destination" ]; then
    echo "[ERROR] 既に存在します: $destination"
    exit 1
  fi

  if command -v curl >/dev/null 2>&1; then
    downloader_cmd=(curl -fL --progress-bar --retry 3 --retry-delay 2 "$url" -o "$tmp_destination")
  elif command -v wget >/dev/null 2>&1; then
    downloader_cmd=(wget -O "$tmp_destination" "$url")
  else
    echo "[ERROR] curl か wget が必要です"
    exit 1
  fi

  echo "[INFO] Downloading to $destination"
  if ! "${downloader_cmd[@]}"; then
    rm -f "$tmp_destination"
    echo "[ERROR] ダウンロードに失敗しました: $url"
    exit 1
  fi
  mv "$tmp_destination" "$destination"
  echo "[INFO] Saved: $destination"
}

function launch_container() {
  if container_running; then
    echo "[INFO] ${container_name} コンテナはすでに起動しています"
    return 0
  fi
  if container_exists; then
    echo "[INFO] ${container_name} コンテナが停止状態で残っています。再作成します"
    docker rm "$container_name" >/dev/null 2>&1 || true
  fi
  if [ -n "$host_comfyui" ]; then
    publish_arg="${host_comfyui}:${host_port}:8188"
    echo "[INFO] Starting ${container_name} on http://${host_comfyui}:${host_port}"
  else
    publish_arg="${host_port}:8188"
    echo "[INFO] Starting ${container_name} on http://127.0.0.1:${host_port}"
  fi
  docker run \
    --gpus=all \
    -d \
    --name "$container_name" \
    --rm \
    -p "$publish_arg" \
    --ipc=host \
    --ulimit memlock=-1 \
    --ulimit stack=67108864 \
    "${docker_options[@]}" \
    "$image_name"
}

case "${subcommand:-}" in
  down)
    if ! container_exists; then
      echo "[INFO] ${container_name} コンテナは起動していません"
      exit 0
    fi
    docker stop "$container_name"
    ;;
  logs)
    if ! container_exists; then
      echo "[ERROR] ${container_name} コンテナが起動していません"
      exit 1
    fi
    docker logs -f "$container_name"
    ;;
  exec)
    if ! container_exists; then
      launch_container
    elif ! container_running; then
      echo "[ERROR] ${container_name} コンテナが停止しています"
      exit 1
    fi
    if [ "${#sub_args[@]}" -eq 0 ]; then
      docker exec -it "$container_name" bash
    else
      docker exec -it "$container_name" "${sub_args[@]}"
    fi
    ;;
  download)
    download_model "${sub_args[@]}"
    ;;
  help|-h|--help)
    show_help
    ;;
  "")
    launch_container
    ;;
  *)
    echo "[ERROR] 存在しないコマンドです: $subcommand"
    echo "[INFO] 'comfyui --help' で使い方を確認してください"
    exit 1
    ;;
esac
