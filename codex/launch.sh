#!/bin/bash

if [ -z "$CODEX_CACHE_DIR" ]; then
  echo "CODEX_CACHE_DIR is not set"
  exit 1
fi

cache_dir="$(realpath "$CODEX_CACHE_DIR")"
src_dir="$cache_dir/src"
container_name="codex"
work_dir="$(pwd)"
options=()
update=0
build=0
for arg in "$@"; do
  case $arg in
    --update)
      update=1
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

mkdir -p "$src_dir"
if [ ! -d "$src_dir/codex" ]; then
  echo
  git clone --recursiv https://github.com/openai/codex.git "$src_dir/codex"
  build=1
fi

if [ "$update" -eq 1 ]; then
  (
    echo "[INFO] Updating source code"
    cd "$src_dir/codex"
    git fetch --all --tags
    git checkout main
    git pull
  )
fi

if [ "$build" -eq 1 ]; then
  (
    echo "[INFO] Building Docker image"
    cd "$src_dir/codex/codex-cli"
    bash scripts/build_container.sh
  )
fi

docker run --rm -it \
  -e OPENAI_API_KEY="$OPENAI_API_KEY" \
  -v "$src_dir/codex:/src" \
  -v "$work_dir:/workdir" \
  -w "/workdir" \
  -u "$(id -u):$(id -g)" \
  codex codex "${options[@]}"
