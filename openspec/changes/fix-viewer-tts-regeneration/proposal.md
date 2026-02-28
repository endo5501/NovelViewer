## Why

閲覧画面でTTS再生/生成を行うと、編集画面で文章ごとにレファレンス音声を設定して生成済みの音声が破棄され、デフォルトのレファレンス音声で再生成されてしまう。編集画面で作成したエピソードに`text_hash`が保存されていないため、閲覧画面の`TtsStreamingController`がハッシュ検証に失敗し、既存のエピソードとセグメントをすべて削除して一から再生成してしまうことが原因。

## What Changes

- `TtsEditController`がエピソードを作成する際に`text_hash`を計算・保存するようにする
- これにより、閲覧画面の`TtsStreamingController.start()`がエピソードを発見した際、ハッシュが一致すれば既存のデータ（セグメントごとのレファレンス音声設定と生成済み音声）を再利用する

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `tts-edit-screen`: エピソード作成時に`text_hash`を計算・保存する要件を追加。`_ensureEpisodeExists()`が`text`パラメータを受け取り、SHA-256ハッシュを`tts_episodes.text_hash`カラムに格納するようにする

## Impact

- `lib/features/tts/data/tts_edit_controller.dart`: `_ensureEpisodeExists()`の修正、`loadSegments()`でテキストを保持
- `tts_streaming_controller.dart`の変更は不要（既存のハッシュ検証ロジックは正しく動作する）
- 既存の`tts-streaming-pipeline`スペックの要件に変更なし
