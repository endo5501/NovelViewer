## Why

TTS worker isolate が Dart 例外（FFI 境界外のエラー、メッセージのデシリアライズ失敗、OOM 等）で死ぬと、`TtsIsolate` の broadcast stream には何も流れず、`TtsSession.synthesize()` / `ensureModelLoaded()` が待つ completer が**永久に未解決**になる。結果、streaming は "waiting" のまま無限ハングし、ユーザは停止も再生もできず、ログにも痕跡が残らない（監査 F144 / 技術的負債テーマ#1「静かな失敗」の積み残し）。

現状 `Isolate.spawn` には通常運用時の `addErrorListener` / `addOnExitListener` が無く（dispose 時に exit を待つコードのみ）、worker の異常終了を検知する経路が存在しない。

## What Changes

- `TtsIsolate.spawn()` で生成した worker isolate に `addErrorListener` と `addOnExitListener` を登録し、**通常運用中の worker 異常終了を検知**する。
- worker 異常終了を検知したら、新レスポンス `WorkerDiedResponse`（`TtsIsolateResponse` の sealed サブタイプ）を broadcast stream へ流す。
- `TtsSession.synthesize()` / `ensureModelLoaded()` の per-call リスナーが `WorkerDiedResponse` を受けたら completer をエラー解決（synthesize は `null`、modelLoad は `false`）し、警告ログを出す。これにより無限ハングが**決定論的に**解消する。
- dispose 起因の正常終了（`DisposeMessage` 送信→worker が receivePort を閉じて終了）を異常終了と誤判定しないよう、`TtsIsolate` に dispose 中フラグを設け、spawn 登録のリスナーを抑止する。
- バックストップとして、`TtsSession` にモデルロードのタイムアウト（注入可能）を追加する。worker が「生きているが native 内で停止」した稀なケースでも completer を解放できるようにする。合成（synthesize）側は長文合成が正当に長時間かかるため固定タイムアウトは設けず、worker 死亡検知を一次対策とする（詳細は design.md）。

## Capabilities

### New Capabilities
- `tts-isolate-resilience`: TTS worker isolate の異常終了（uncaught error / 予期しない exit）を検知し、待機中の操作を決定論的にエラー解決して無限ハングを防ぐ、isolate/session のライフサイクル堅牢性。

### Modified Capabilities
（なし — 既存 spec の要件は変更しない。streaming/edit の振る舞いは「ハングしなくなる」点を除き不変）

## Impact

- `lib/features/tts/data/tts_isolate.dart` — `spawn()` にエラー/exit リスナー登録、`WorkerDiedResponse` 追加、dispose 中フラグ。
- `lib/features/tts/data/tts_session.dart` — `synthesize()` / `ensureModelLoaded()` のリスナーで `WorkerDiedResponse` を処理、モデルロードタイムアウト（注入可能）追加。
- テスト: worker をわざと異常終了させる fake / 注入で TtsSession・TtsIsolate の no-hang 契約を検証（F158 のカバレッジ穴も一部補完）。
- 影響範囲は TtsIsolate/TtsSession に閉じ、streaming controller・edit controller の呼び出し契約（戻り値の意味）は不変。ネイティブ（C/FFI）変更なし。
