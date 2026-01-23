#! /bin/bash

if [ -z "$TOOLS_GIT_CACHE_DIR" ]; then
  echo "TOOLS_GIT_CACHE_DIR is not set"
  exit 1
fi

tool_name=langfuse
tools_git_cache="$TOOLS_GIT_CACHE_DIR/$tool_name"
repo=https://github.com/langfuse/langfuse.git
docker_compose_dir="$tools_git_cache"
container_name=langfuse-web

if [ ! -d "$tools_git_cache" ]; then
  echo "[INFO] ${tool_name} リポジトリが存在しないのでクローンします"
  mkdir -p "$tools_git_cache"
  git clone "$repo" "$tools_git_cache"
# else
#   echo "[INFO] ${tool_name} リポジトリが存在するのでpullします"
#   git -C "$tools_git_cache" pull
fi

if ! docker ps -a --format '{{.Names}}' | grep -wq "$container_name"; then
  echo "[INFO] ${container_name} コンテナが存在しないので作成します"
  (
    cd "$docker_compose_dir"
    docker compose up -d --build
  )
fi

show_help() {
  echo "Usage: $0 [command]"
  echo
  echo "Commands:"
  echo "  help, -h, --help  Show this help message"
  echo "  down              Stop and remove the container"
  echo "  logs              Show the logs of the container"
  echo "  [command]         Execute the command in the container"
  echo
  echo "Ports:"
  echo "  8080 Langfuse HTTP"
}

if [ $# -eq 0 ]; then
  docker exec -it "$container_name" bash
else
  case "$1" in
    "help"|"-h"|"--help")
      show_help
      ;;
    "down")
      (
        cd "$docker_compose_dir"
        docker compose down
      )
      ;;
    "logs")
      docker logs -f "$container_name"
      ;;
    *)
      if ! docker exec "$container_name" "$@"; then
        echo "[ERROR] コマンドの実行に失敗しました"
        exit 1
      fi
      ;;
  esac
fi
