#! /bin/bash
SRC="${1:?ソースコードのパス}"
SRC="$(cd "$SRC" && pwd)"

cd "$(dirname "$0")" || exit 1
docker build -t instant-ngp .
xhost +local:
docker run --rm -it \
	--shm-size=8g \
	-e DISPLAY="$DISPLAY" -v /tmp/.X11-unix/:/tmp/.X11-unix:ro \
	-v "$SRC:/work" \
	-w /work \
	--gpus all \
	instant-ngp \
	bash
