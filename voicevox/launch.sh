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

function launch_container() {
  if ! docker ps -a --format '{{json .Names}}' | jq -e --arg name "$container_name" '. == $name' > /dev/null; then
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
  if ! docker ps -a --format '{{.Names}}' | grep -wq "$container_name"; then
    echo "[INFO] 起動していません"
    exit 0
  fi
  docker stop "$container_name"
  exit 0
fi

launch_container
if [ $# -eq 0 ]; then
  docker exec -it "$container_name" bash
else
  case "$1" in
    exec)
      docker exec "$container_name" "$@"
      ;;
    logs)
      docker logs -f "$container_name"
      ;;
    *)
      echo "[ERROR] 存在しないコマンドです。"
      ;;
  esac
fi
