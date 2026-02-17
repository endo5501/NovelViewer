## Why

Ollamaプロバイダでモデル名を手入力する現在のUIは、ユーザーがモデル名を正確に把握している必要があり不便である。OllamaはAPIでインストール済みモデル一覧を取得できる（`GET /api/tags`）ため、これを活用してドロップダウン選択UIに変更する。

## What Changes

- Ollamaサーバからインストール済みモデル一覧を取得する機能を追加
- Ollamaのモデル名入力フィールドをドロップダウン選択に変更
- Ollama選択時にモデル一覧を自動取得し、更新ボタンで再取得可能にする
- サーバ未起動・接続失敗時はエラー表示（手入力フォールバックなし）

## Capabilities

### New Capabilities
- `ollama-model-list`: Ollamaサーバからモデル一覧を取得し、ドロップダウンで選択するUI

### Modified Capabilities
- `llm-settings`: Ollamaのモデル設定を手入力からドロップダウン選択に変更

## Impact

- `lib/features/llm_summary/data/ollama_client.dart` — モデル一覧取得メソッド追加
- `lib/features/settings/presentation/settings_dialog.dart` — Ollamaモデル選択UIの変更
- Ollama API `/api/tags` エンドポイントへの新規依存
