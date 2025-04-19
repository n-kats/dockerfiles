#!/bin/bash

if [ -z "$OLLAMA_CACHE_DIR" ]; then
  echo "OLLAMA_CACHE_DIR is not set"
  exit 1
fi

ollama_cache="$(realpath "$OLLAMA_CACHE_DIR")"
container_name="ollama"
port=${OLLAMA_PORT:-11434}

if ! docker ps -a --format '{{.Names}}' | grep -wq "$container_name"; then
  echo "[INFO] ${container_name} コンテナが存在しないので作成します"
  docker run --gpus=all \
    -d \
    --name "$container_name" \
    --rm \
    -v "$ollama_cache:/root/.ollama" \
    -e OLLAMA_HOST=0.0.0.0:11434 \
    -e OLLAMA_ORIGIN=* \
    -p $port:11434 \
    --ipc=host --ulimit memlock=-1 --ulimit stack=67108864 \
    ollama/ollama
fi

function show_help() {
  echo "  help    Show this help message(-h, --help)"
  echo "  down    Stop the ollama container"
  echo "  exec    Execute a command in the ollama container"
  echo "  logs    Show the logs of the ollama container"
  echo "  run     Run a command in the ollama container"
  echo ""
}

if [ $# -eq 0 ]; then
  docker exec -it "$container_name" ollama
else
  case "$1" in
    help|-h|--help)
      echo "[INFO] ラッパーのヘルプを表示します。"
      show_help
      echo "[INFO] ollama commandのヘルプを表示します。"
      docker exec "$container_name" ollama "$@"
      ;;
    down)
      docker stop "$container_name"
      ;;
    exec)
      docker exec "$container_name" "$@"
      ;;
    logs)
      docker logs "$container_name"
      ;;
    run)
      docker exec -it "$container_name" ollama "$@"
      ;;
    *)
      docker exec "$container_name" ollama "$@"
      ;;
  esac
fi
