## Why

`TtsStoredPlayerController` のテストが約5回に1回の頻度で失敗する。原因は `stop()` 内の非同期処理のレースコンディション：`_onSegmentCompleted` が `stop()` を fire-and-forget で呼び、テストの `tearDown` がファイル削除より先に一時ディレクトリを削除してしまうことがある。

## What Changes

- `stop()` 内の処理順序を変更：`_cleanupFiles()` を Provider 状態更新の前に実行し、テスト側の `_pumpUntil` が `stopped` を検出した時点でファイル削除が完了済みであることを保証する
- `_cleanupFiles()` に防御的エラーハンドリングを追加：`PathNotFoundException` を無視し、既に削除されたファイルへのアクセスを安全に処理する

## Capabilities

### New Capabilities

なし（既存機能のバグ修正のため）

### Modified Capabilities

なし（要件レベルの変更はなく、実装の堅牢性向上のみ）

## Impact

- `lib/features/tts/data/tts_stored_player_controller.dart` — `stop()` と `_cleanupFiles()` の修正
- `test/features/tts/data/tts_stored_player_controller_test.dart` — テストの安定性が向上
