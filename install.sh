#!/bin/bash
cd "$(dirname "$(realpath "$0")")"
find . -maxdepth 1 -type d | while read -r line; do
  if [ "$line" = "." ]; then
    continue
  fi
  name="$(basename "$line")"

  case "$name" in
    .git|legacy)
      continue
      ;;
    *)
      if [ -e "$name/launch.sh" ]; then
        if [ -e "$HOME/bin/$name" ] || [ -L "$HOME/bin/$name" ]; then
          echo "[INFO] $name はインストール済みです"
          continue
        fi
        echo "[INFO] $name をインストールします"
        mkdir -p "$HOME/bin"
        ln -sf "$(realpath "$line/launch.sh")" "$HOME/bin/$name"
        chmod +x "$HOME/bin/$name"
      fi
      ;;
  esac
done
