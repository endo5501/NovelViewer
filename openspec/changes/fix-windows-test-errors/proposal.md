## Why

WindowsとmacOSの両方でテストを実行する必要があるが、現在6つのテストがWindowsでのみ失敗する。原因はパスセパレーターの違い（macOS: `/`, Windows: `\`）で、テストコードがUnixスタイルのパス(`/`)をハードコードしている。macOSでは問題にならないが、Windowsでは`\`が使われるため不一致が発生する。

## What Changes

- TTSモデルダウンロード関連のテストコードにおけるパスセパレーターの期待値を、プラットフォーム非依存な方法に修正する
- 対象テストファイル:
  - `test/features/tts/data/tts_model_download_service_test.dart` (1 failure: `resolveModelsDir`)
  - `test/features/tts/providers/tts_model_download_providers_test.dart` (3 failures: `modelsDirectoryPathProvider`, `download transitions to completed`, `completed state includes models directory path`)
  - `test/features/settings/presentation/tts_model_download_ui_test.dart` (2 failures: `shows completed status when models already exist`, `auto-fills model directory after download`)

## Capabilities

### New Capabilities

(なし — 新しい機能は追加しない)

### Modified Capabilities

- `tts-model-download`: テストにおけるパス結合方法をプラットフォーム非依存に修正。実装コード(`resolveModelsDir`等)がDartの`path`パッケージ(`p.join`)を使ってパス結合しており、Windowsでは`\`を返す。テスト側の期待値もそれに合わせる。

## Impact

- 影響範囲はテストコードのみ（3ファイル、6テストケース）
- 実装コードの変更は不要（実装はすでに`path`パッケージを使用しており正しく動作している）
- macOSでのテスト結果に影響なし
