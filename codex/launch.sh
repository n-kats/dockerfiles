#!/bin/bash

if [ -z "$CODEX_CACHE_DIR" ]; then
  echo "CODEX_CACHE_DIR is not set"
  exit 1
fi

dockerfile_dir="$(dirname "$(realpath "$0")")/docker"
cache_dir="$(realpath "$CODEX_CACHE_DIR")"
src_dir="$cache_dir/src"
container_name="codex"
work_dir="$(pwd)"
docker_options=()
build=0
for arg in "$@"; do
  case $arg in
    --update)
      build=1
      ;;
    --workdir)
      work_dir="$(realpath "$2")"
      shift
      ;;
    *)
      options+=("$arg")
      ;;
  esac
done

if [ ! -d $work_dir ]; then
  echo "[ERROR] Work directory does not exist: $work_dir"
  exit 1
fi

if [ "$build" -eq 1 ]; then
  (
    echo "[INFO] Building Docker image"
    docker build --build-arg TIMESTAMP=$(date +%Y%m%d_%H%M%S) -t my-codex "$dockerfile_dir"
  )
fi

home_dir_in_docker=/home/ubuntu
docker run --rm -it \
  -v "$src_dir/codex:/src" \
  -v "$cache_dir/cache:$home_dir_in_docker/.cache" \
  -v "$cache_dir/local:$home_dir_in_docker/.local" \
  -v "$cache_dir/codex:$home_dir_in_docker/.codex" \
  -v "$cache_dir/npm_cache:$home_dir_in_docker/.npm" \
  -v "$cache_dir/pnpm_cache:$home_dir_in_docker/.pnpm-store" \
  -v "$cache_dir/yarn_cache:$home_dir_in_docker/.cache/yarn" \
  -v "$cache_dir/bun_cache:$home_dir_in_docker/.bun" \
  -v "$work_dir:/workspace" \
  -w "/workspace" \
  -u "$(id -u):$(id -g)" \
  --network host \
  my-codex bash -c "
alias apply_patch=patch
codex "${options[@]}"
"
