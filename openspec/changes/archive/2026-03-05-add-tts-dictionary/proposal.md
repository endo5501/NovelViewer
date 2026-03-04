## Why

小説の読み上げ時、人名や固有名詞の特殊な読み方を毎回セグメント編集で手修正する必要があり、同じ単語が繰り返し出現するたびに修正コストが発生する。表記と読みのペアを辞書として登録し、TTS入力テキスト生成時に自動変換することで、この繰り返し作業を解消する。

## What Changes

- 各小説フォルダに辞書専用のSQLiteデータベースファイル（`tts_dictionary.db`）を新規作成し、表記→読みのペアを管理する
- TTS編集ダイアログに辞書管理タブ（または画面）を追加し、ユーザーが表記と読みのペアを登録・編集・削除できるようにする
- TTS入力テキストを生成する際（`TtsStreamingController.start()` および編集画面でのオンデマンド生成時）に、辞書の登録内容を適用してテキストを変換する

## Capabilities

### New Capabilities

- `tts-dictionary`: 小説ごとのTTS読み上げ辞書機能。表記と読みのペアをSQLiteで永続化し、CRUD操作とTTSテキストへの適用を提供する

### Modified Capabilities

- `tts-edit-screen`: 辞書管理UIをTTS編集ダイアログに追加（辞書タブまたはボタンからアクセス）
- `tts-streaming-pipeline`: `start()` 呼び出し時に辞書変換を適用してTTSエンジンに渡すテキストを生成する

## Impact

- **新規ファイル**: `lib/features/tts/data/tts_dictionary_database.dart`、`lib/features/tts/data/tts_dictionary_repository.dart`、`lib/features/tts/presentation/tts_dictionary_dialog.dart`（または`tts_dictionary_tab.dart`）
- **変更ファイル**: `lib/features/tts/presentation/tts_edit_dialog.dart`（辞書UIへのアクセス追加）、`lib/features/tts/data/tts_streaming_controller.dart`（辞書変換適用）、`lib/features/tts/data/tts_edit_controller.dart`（辞書変換適用）
- **新規テスト**: 辞書CRUD、テキスト変換ロジック、UI統合テスト
- **依存関係**: 既存の`sqflite`パッケージを流用（新規依存なし）
