## Why

読み上げ編集画面の「全生成」機能において、中断操作が見た目上のみで実際にはバックグラウンドの TTS 合成が続行する問題がある。現在の実装では `_cancelled` フラグを設定して次のセグメントの生成開始を阻止するが、現在進行中の Isolate 内の合成処理は完了まで続く。加えて、UI は中断ボタン押下と同時に idle 状態に遷移するため、ユーザーには中断が完了したように見えるが、実際にはバックグラウンドで生成が継続している。また、生成中の状態表示がツールバー右上にあるため、どのセグメントが生成中かが直感的にわかりにくい。

## What Changes

- **全生成の中断処理を実効的にする**: 中断時に TTS Isolate を dispose して実際に合成処理を停止する。中断後に再度生成を開始できるよう、Isolate を再作成する仕組みを追加する。
- **生成中の状態表示を改善する**: ツールバー右上の `CircularProgressIndicator` を廃止し、生成中のセグメント行のステータスアイコンにスピナーを表示する形に変更する。これにより、現在どのセグメントが処理中かを行単位で把握できるようにする。
- **中断ボタンの位置を維持**: ツールバーの中断ボタンは引き続きツールバーに配置する（全生成ボタンの代わりに表示）。

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `tts-edit-screen`: 全生成の中断処理を、フラグベースから Isolate dispose ベースに変更し、実際にバックグラウンド生成を停止する。生成中の状態表示をツールバーからセグメント行のアイコン列に移動する。

## Impact

- `lib/features/tts/data/tts_edit_controller.dart`: `cancel()` メソッドの改修（Isolate dispose + 再作成）、`generateAllUngenerated()` の中断処理改善
- `lib/features/tts/presentation/tts_edit_dialog.dart`: ツールバーの生成中表示を削除、中断ボタンのレイアウト変更、セグメント行のステータスアイコンへのスピナー表示（既存の仕組みを活用）
- `lib/features/tts/data/tts_isolate.dart`: dispose 後の再作成をサポートする必要がある場合の変更
- `lib/features/tts/providers/tts_edit_providers.dart`: 状態管理の変更は最小限（既存の `ttsEditGeneratingIndexProvider` を活用）
- テスト: 中断操作の実効性を検証するテストの追加
