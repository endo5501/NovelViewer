## Why

編集画面で「全生成」を実行した後、画面を閉じて再度開くと、各セグメントのリファレンス音声が "設定値" から "なし" に変わってしまう。`TtsEditController.generateSegment()` が合成用に解決されたフルパスをDBに保存しているため、再読み込み時にファイル名リストとマッチせず "なし" と表示される。閲覧画面からの連続生成では発生しない。

## What Changes

- `TtsEditController.generateSegment()` の `insertSegment()` 呼び出しで、合成用に解決された `refWavPath` パラメータではなく、セグメントのメタデータである `segment.refWavPath` を保存するように修正

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `tts-edit-screen`: セグメント新規挿入時に保存するリファレンス音声パスを、合成用フルパスからセグメントのメタデータ値に修正

## Impact

- `lib/features/tts/data/tts_edit_controller.dart` の `generateSegment()` メソッド（1行変更）
- 既存のDBデータには影響なし（既に保存済みのフルパスは再生成またはリセットで修正される）
