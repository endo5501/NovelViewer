## Why

現在、TTSモデルデータ（GGUFファイル）のセットアップにはユーザがPythonスクリプトを使ってモデル変換を行い、手動でファイルを配置し、設定画面からパスを指定する必要がある。この手順は複雑で手間がかかるため、多くのユーザにとって障壁となっている。HuggingFaceのkoboldcppリポジトリで変換済みモデルが公開されたことで、ワンクリックでモデルをダウンロードできる仕組みが実現可能になった。

## What Changes

- 設定画面の「読み上げ」タブに「モデルデータダウンロード」ボタンを追加
- HuggingFaceから以下2つのGGUFファイルをダウンロードする機能を実装:
  - `qwen3-tts-0.6b-f16.gguf`（メインモデル）
  - `qwen3-tts-tokenizer-f16.gguf`（トークナイザー）
- ダウンロード先はテキストデータ保存先（NovelViewerディレクトリ）と同階層の `models` フォルダに自動配置
- ダウンロード完了後、モデルディレクトリパスを自動設定

## Capabilities

### New Capabilities
- `tts-model-download`: HuggingFaceからTTSモデルデータ（GGUFファイル）をダウンロードし、所定のディレクトリに保存する機能。ダウンロード進捗表示、エラーハンドリング、既存ファイルの検出を含む。

### Modified Capabilities
- `tts-settings`: 「読み上げ」タブにモデルデータダウンロードUIを追加。ダウンロードボタン、進捗表示、ダウンロード状態の表示を含む。

## Impact

- **UI**: 設定ダイアログの「読み上げ」タブにダウンロード関連UIを追加
- **依存パッケージ**: 既存の `http` パッケージを利用（新規依存なし）
- **ファイルシステム**: NovelViewerディレクトリと同階層に `models` フォルダを作成
- **ネットワーク**: HuggingFace (`huggingface.co`) へのHTTPSアクセスが必要
- **既存コード**: `NovelLibraryService` のパス解決ロジックを参照してダウンロード先を決定
