#!/bin/bash

if [ -z "$DIFY_CACHE_DIR" ]; then
  echo "DIFY_CACHE_DIR is not set"
  exit 1
fi

cache_dir="$(realpath "$DIFY_CACHE_DIR")"
src_dir="$cache_dir/src"

if [ ! -d "$src_dir" ]; then
  echo "[INFO] Creating source directory: $src_dir"
  mkdir -p "$src_dir"
  git clone https://github.com/langgenius/dify.git "$src_dir"
fi

version="$DIFY_VERSION"

if [ "$version" != "" ]; then
  (
    echo "[INFO] Checking out version: $version"
    cd "$src_dir"
    git fetch --all --tags
    git checkout "$version"
  )
fi

here="$(dirname "$(realpath "$0")")"
env_file="$here/.env"
container_name="dify"

if ! docker ps --format '{{.Image}}' | grep -q 'dify'; then
  (
    cd "$src_dir/docker"
    docker compose --env-file "$env_file" up --build -d
  )
else
  echo "[INFO] A container using a 'dify' image is already running."
fi

if [ "$1" = "down" ] ; then
  (
    cd "$src_dir/docker"
    docker compose --env-file "$env_file" down
  )
fi
