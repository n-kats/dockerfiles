#!/bin/bash

container_name="voicevox"

function show_help() {
  echo "  help    Show this help message(-h, --help)"
  echo "  down    Stop the voicevox container"
  echo "  exec    Execute a command in the voicevox container"
  echo "  logs    Show the logs of the voicevox container"
  echo ""
  echo " Ports:"
  echo "  50021 VoiceVox API"
}

function container_exists() {
  # `name` フィルタは部分一致なので、^/NAME$ で完全一致にする。
  [[ -n "$(docker ps -aq --filter "name=^/${container_name}$")" ]]
}

function launch_container() {
  if ! container_exists; then
    echo "[INFO] ${container_name} コンテナが存在しないので作成します"
    docker run --gpus=all \
      -d \
      --name "$container_name" \
      --rm \
      -p 50021:50021 \
      voicevox/voicevox_engine:nvidia-latest
  fi
}

if [ "$1" = "help" ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  show_help
  exit 0
fi

if [ "$1" = "down" ]; then
  if ! container_exists; then
    echo "[INFO] 起動していません"
    exit 0
  fi
  docker stop "$container_name"
  exit 0
fi

if [ $# -eq 0 ]; then
  launch_container
  docker exec -it "$container_name" bash
else
  case "$1" in
    exec)
      launch_container
      docker exec "$container_name" "$@"
      ;;
    logs)
      if ! container_exists; then
        echo "[ERROR] ${container_name} コンテナが起動していません"
        exit 1
      fi
      docker logs -f "$container_name"
      ;;
    *)
      echo "[ERROR] 存在しないコマンドです。"
      ;;
  esac
fi
