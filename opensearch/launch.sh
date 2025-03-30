#!/bin/bash

if [ -z "$OPENSEARCH_CACHE" ]; then
  echo "OPENSEARCH_CACHE is not set"
  exit 1
fi

opensearch_cache=$(realpath "$OPENSEARCH_CACHE")
container_name="opensearch"

if ! docker ps -a --format '{{.Names}}' | grep -wq "$container_name"; then
  echo "[INFO] ${container_name} コンテナが存在しないので作成します"
  (
    cd "$dirname $(realpath "$0")"
    docker compose up -d
  )
fi

if [ $# -eq 0 ]; then
  docker exec -it "$container_name" bash
elif [ "$1" = "down" ]; then
  (
    cd "$dirname $(realpath "$0")"
    docker compose down
  )
else
  docker exec "$container_name" "$@"
fi
