## Why

閲覧画面でTTS再生/生成を行うと、編集画面で文章ごとにレファレンス音声を設定して生成済みの音声が破棄され、デフォルトのレファレンス音声で再生成されてしまう。3つの原因がある:

1. 編集画面で作成したエピソードに`text_hash`が保存されていないため、閲覧画面の`TtsStreamingController`がハッシュ検証に失敗し、既存のエピソードとセグメントをすべて削除して一から再生成してしまう
2. `TtsStreamingController`がDBから読んだセグメントの`ref_wav_path`（ファイル名のみ）をフルパスに解決せずにTTSエンジンに渡すため、音声合成が失敗して即終了する
3. `TtsStreamingController`が新規セグメントの`ref_wav_path`にフルパスを保存するため、編集画面がファイル名リストと照合できず「なし」と表示される

## What Changes

- `TtsEditController`がエピソードを作成する際に`text_hash`を計算・保存するようにする
- `TtsStreamingController`がDBから読んだ`ref_wav_path`をフルパスに解決してからTTSエンジンに渡す
- `TtsStreamingController`が新規セグメント挿入時に`ref_wav_path`をNULL（設定値）として保存する

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `tts-edit-screen`: エピソード作成時に`text_hash`を計算・保存する要件を追加
- `tts-streaming-pipeline`: セグメントの`ref_wav_path`をフルパスに解決してから合成する要件を追加。新規セグメント挿入時にグローバル設定のフルパスではなくNULLを保存する要件を追加

## Impact

- `lib/features/tts/data/tts_edit_controller.dart`: `_ensureEpisodeExists()`の修正、`loadSegments()`でテキストハッシュを保持
- `lib/features/tts/data/tts_streaming_controller.dart`: `ref_wav_path`のパス解決ロジック追加、`insertSegment`の`refWavPath`引数修正
- `lib/features/text_viewer/presentation/text_viewer_panel.dart`: `resolveRefWavPath`コールバックの受け渡し
