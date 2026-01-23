# Repository Guidelines

## 言語

コミュニケーション（イシュー/プルリク/レビュー/コメント）は日本語を優先します（コマンドや設定キー等は原文のまま）。

## プロジェクト構成

このリポジトリは、複数ツールを Docker で起動するためのラッパー（`launch.sh`）と関連 Dockerfile/Docker Compose をまとめた集約です。

### 共通ディレクトリパターン（〜型）

- **Docker run型**: `launch.sh` が `docker run` でコンテナを起動（必要なら `<tool>/docker/` を `docker build` してから実行）
- **Docker Compose型**: `launch.sh` が `docker compose up/down` で起動（必要ならアップストリームを `$*_CACHE_DIR` 配下へクローンしてから起動）

### ディレクトリ一覧（1行1ディレクトリ）

- `ccodex/`: Docker run型（`docker/` あり、`samples/` に初期設定例）
- `codex/`: Docker run型（`docker/` あり）
- `gemini/`: Docker run型（`docker/` あり）
- `opensearch/`: Docker Compose型（ポート: `9200`, `9600`, `5601`）
- `ollama/`: Docker run型（永続化: `OLLAMA_CACHE_DIR`、ポート既定: `11434`）
- `voicevox/`: Docker run型（`jq` を使用、ポート: `50021`）
- `dify/`: Docker Compose型（アップストリームを `DIFY_CACHE_DIR` 配下へクローン、設定: `dify/.env`）
- `langfuse/`: Docker Compose型（アップストリームを `TOOLS_GIT_CACHE_DIR` 配下へクローン）
- `legacy/`: 過去資産（基本メンテ対象外）

### ルート直下

- `install.sh`: `~/bin/<tool>` に各 `launch.sh` のシンボリックリンクを作成（`.git` と `legacy/` は除外）

## ビルド/開発コマンド

前提: `docker`, `docker compose`（`voicevox` は `jq` を使用）, 必要に応じて NVIDIA GPU/driver。

- `./install.sh`: 主要ツールのランチャーを `~/bin` にインストール
- `./<tool>/launch.sh --help`: 使い方とオプション確認（例: `--update`, `--workdir`, `--setup`, `down`, `logs`）
- `./opensearch/launch.sh`: `docker compose up -d --build` と `exec/logs` のラッパー
- `./dify/launch.sh` / `./langfuse/launch.sh`: 初回はアップストリームのクローンを実行してから `docker compose up`

環境変数（必須のものが多い）例:
`CODEX_CACHE_DIR`, `GEMINI_CLI_CACHE_DIR`, `TOOLS_GIT_CACHE_DIR`, `DIFY_CACHE_DIR`, `OLLAMA_CACHE_DIR`.

## コーディング規約

- Bash 前提（`#!/bin/bash`、配列利用あり）: 2スペースインデント、変数は基本クォート（`"$var"`）して安全に扱う
- 変更時は `--help` の表示とエラーメッセージ（`[INFO]`, `[ERROR]`）も合わせて更新
- ディレクトリ名はツール名（例: `opensearch/`）。Docker イメージ名はスクリプト内の定数（例: `my-codex`, `custom-codex`）を尊重

## セキュリティ/設定の注意点

- 秘密情報はコミットしない（`.env` はテンプレートとして扱い、ローカル差し替え/シンボリックリンクを推奨）
- 例: `ln -s /secure/path/.env dify/.env`、`chmod 600 dify/.env`
