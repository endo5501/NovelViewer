## Why

現在TTSモデルは0.6Bのみ対応しており、koboldcppのHuggingFaceリポジトリからダウンロードしている。1.7Bモデルのサポートが追加されたため、ユーザーが高速(0.6B)と高精度(1.7B)を設定画面で切り替えられるようにし、ダウンロード元も自前リポジトリ(`endo5501/qwen3-tts.cpp`)に移行する。

## What Changes

- 設定画面の読み上げタブにモデルサイズ選択UI（SegmentedButton）を追加（高速 0.6B / 高精度 1.7B）
- ダウンロードURLを `koboldcpp/tts` から `endo5501/qwen3-tts.cpp` に変更
- モデルをサイズ別サブディレクトリ（`models/0.6b/`, `models/1.7b/`）に保存するよう変更
- tokenizerファイルは各サブディレクトリに重複保存（管理のシンプルさ優先）
- モデルディレクトリ設定フィールドを削除し、モデルサイズ選択に応じた自動管理に変更 **BREAKING**
- 旧ディレクトリ構造（`models/` 直下）から新構造（`models/0.6b/`）への自動マイグレーション
- 選択中モデルが未ダウンロードならダウンロードボタン表示、DL済みなら即切替

## Capabilities

### New Capabilities
- `tts-model-selection`: TTSモデルサイズ（0.6B/1.7B）の選択・切替機能と、旧ディレクトリ構造からの自動マイグレーション

### Modified Capabilities
- `tts-model-download`: ダウンロードURLの変更、モデルサイズ別サブディレクトリへの保存、モデルサイズに応じたファイルリスト
- `tts-settings`: モデルディレクトリ手動設定の削除、モデルサイズ選択設定の追加、モデルサイズに基づくディレクトリ自動算出

## Impact

- `TtsModelDownloadService`: URL変更、モデルサイズ引数追加、サブディレクトリ対応
- `SettingsDialog`: 読み上げタブのUI大幅変更（モデルディレクトリ削除、SegmentedButton追加）
- `SettingsRepository` / providers: `tts_model_dir` → `tts_model_size` 設定キー変更
- `TtsEngine` / `TtsIsolate`: モデルディレクトリ解決ロジックの変更（サイズ→パス自動算出）
- 既存ユーザーのマイグレーション: `models/` 直下のファイルを `models/0.6b/` に移動
