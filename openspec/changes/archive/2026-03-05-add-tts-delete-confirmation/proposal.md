## Why

閲覧画面（text_viewer_panel）でTTS音声データの削除ボタンを押すと、確認なしに即座に削除されてしまう。生成に時間がかかるデータであり、誤操作による削除を防ぐため、削除前に確認ダイアログを表示するべきである。

## What Changes

- 閲覧画面のTTS音声削除ボタン押下時に確認ダイアログを表示する
- ユーザーが確認した場合のみ削除を実行する

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `tts-stored-playback`: 「Delete stored audio」要件に確認ダイアログの表示を追加

## Impact

- `lib/features/text_viewer/presentation/text_viewer_panel.dart` の `_deleteAudio` メソッド周辺
