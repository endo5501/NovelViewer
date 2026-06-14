## 1. TtsSession: worker 死亡シグナルとタイムアウト（テストファースト）

- [x] 1.1 fake `TtsIsolate`（制御可能な `responses` stream）を使い、`synthesize()` 待機中に `WorkerDiedResponse` を流すと `null` を返し警告ログが出ることを検証する失敗テストを追加
- [x] 1.2 同様に `ensureModelLoaded()` 待機中に `WorkerDiedResponse` で `false` を返すテストを追加
- [x] 1.3 `ensureModelLoaded()` の注入タイムアウト経過で `false`＋警告ログ、タイムアウト前の成功で `true` を返すテストを追加
- [x] 1.4 テストを実行し、失敗（未実装）を確認する
- [x] 1.5 `tts_session.dart`: synthesize/ensureModelLoaded の per-call リスナーに `WorkerDiedResponse` 分岐を追加し completer をエラー解決（synthesize=null / modelLoad=false）＋警告ログ
- [x] 1.6 `tts_session.dart`: コンストラクタに注入可能な `modelLoadTimeout`（既定 120 秒）を追加し `ensureModelLoaded()` の待機を `.timeout()` でラップ（タイムアウト時は警告ログ＋false）
- [x] 1.7 1.1–1.3 のテストが通ることを確認

## 2. TtsIsolate: worker 異常終了検知（テストファースト）

- [x] 2.1 `WorkerDiedResponse`（`TtsIsolateResponse` の sealed サブタイプ・理由文字列を保持）を追加
- [x] 2.2 worker から意図的に throw / 異常終了させる注入経路（テスト専用 entrypoint かエラー注入メッセージ）を用意し、`addErrorListener` 発火で `WorkerDiedResponse` が responses stream に1回流れる失敗テストを追加
- [x] 2.3 error と exit の二重発火でも `WorkerDiedResponse` が高々1回であることを検証するテストを追加
- [x] 2.4 正常 `dispose()` では `WorkerDiedResponse` が流れないことを検証するテストを追加
- [x] 2.5 テストを実行し、失敗（未実装）を確認する
- [x] 2.6 `tts_isolate.dart`: `spawn()` で `addErrorListener` / `addOnExitListener` を登録し、発火時に冪等な `_handleWorkerDeath(reason)` で `WorkerDiedResponse` を1回だけ流す（送信済みフラグ）
- [x] 2.7 `tts_isolate.dart`: `bool _disposing` を追加し `dispose()` 先頭で true に。`_handleWorkerDeath` は `_disposing` 時は抑止。検知後は `_sendPort=null` 等で以降の send を無効化
- [x] 2.8 死亡検知経路では abort handle を free しない（F111 UAF 回帰防止）ことを確認し、必要ならテストで固定
- [x] 2.9 2.2–2.4 のテストが通ることを確認

## 3. 統合・回帰確認

- [x] 3.1 spawn 登録リスナーと既存 `dispose()` 内 exit 待ち（`exitPort.first.timeout`）が両立し、graceful shutdown が従来どおり動くことを確認
- [x] 3.2 streaming controller / edit controller の呼び出し契約（戻り値の意味）が不変であることを既存テストで確認
- [x] 3.3 可能なら実 isolate の自然死を1ケース統合テストで担保（DLL 不在時は self-skip 方針に従う）

## 4. 最終確認

- [x] 4.1 code-reviewスキルを使用してコードレビューを実施（findings A: 死亡後の2回目操作ハング、B: spawn前死亡ハング を修正）
- [x] 4.2 codexスキルを使用して現在開発中のコードレビューを実施（spawn レースを onError/onExit のアトミック武装で根絶）
- [x] 4.3 `fvm flutter analyze`でリントを実行（No issues found）
- [x] 4.4 `fvm flutter test`でテストを実行（2077 passed）
