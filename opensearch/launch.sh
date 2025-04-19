#!/bin/bash

container_name="opensearch"
container_dashboard_name="opensearch-dashboards"

if ! docker ps -a --format '{{.Names}}' | grep -wq "$container_name"; then
  echo "[INFO] ${container_name} コンテナが存在しないので作成します"
  (
    cd "$(dirname $(realpath "$0"))"
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
  echo "  logs-dashboard    Show the logs of the dashboard container"
  echo "  [command]         Execute the command in the container"
  echo
  echo "Ports:"
  echo "  9200 OpenSearch HTTP"
  echo "  9600 OpenSearch Analysis"
  echo "  5601 OpenSearch Dashboards"
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
        cd "$(dirname $(realpath "$0"))"
        docker compose down
      )
      ;;
    "logs")
      docker logs -f "$container_name"
      ;;
    "logs-dashboard")
      docker logs -f "$container_dashboard_name"
      ;;
    *)
      if ! docker exec "$container_name" "$@"; then
        echo "[ERROR] コマンドの実行に失敗しました"
        exit 1
      fi
      ;;
  esac
fi
