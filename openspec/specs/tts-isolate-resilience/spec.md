## Purpose

Worker isolate の異常終了（uncaught error / 予期しない exit）を検知し、待機中の TTS 操作を決定論的にエラー解決することで、worker 死亡やモデルロード停止に起因する無限ハングを防ぐ。`TtsIsolate` が死亡を検知して `WorkerDiedResponse` を broadcast し、`TtsSession` がそれを受けて `ensureModelLoaded()`/`synthesize()` の完了待ちを解放する。dispose による正常終了は異常終了として扱わず、モデルロードには注入可能なタイムアウトを設けて worker 生存下の停止にも備える。

## Requirements

### Requirement: Worker isolate 異常終了の検知

`TtsIsolate` は、`spawn()` で起動した worker isolate に対し、通常運用中の異常終了を検知する手段を登録 SHALL する。具体的には、worker の uncaught error を受け取る error リスナーと、worker の予期しない終了を受け取る exit リスナーを登録 SHALL する。いずれかが発火した場合、`TtsIsolate` は `TtsIsolateResponse` の sealed サブタイプ `WorkerDiedResponse`（失敗理由の文字列を保持）を broadcast レスポンス stream へ流 SHALL す。同一の死亡イベントに対して `WorkerDiedResponse` は高々1回だけ流 SHALL し（error と exit の二重発火を集約）、検知後は以降の send を無効化 SHALL する。

#### Scenario: worker が uncaught error で死ぬ

- **WHEN** worker isolate が try/catch の外で uncaught error により終了する
- **THEN** error リスナーが発火し、`TtsIsolate` は失敗理由を保持した `WorkerDiedResponse` を responses stream へ1回流す

#### Scenario: worker がエラーを伴わず予期せず終了する

- **WHEN** worker isolate が error を伴わずに予期せず終了する
- **THEN** exit リスナーが発火し、`TtsIsolate` は `WorkerDiedResponse` を responses stream へ流す

#### Scenario: error と exit が両方届いても通知は1回

- **WHEN** 1回の worker 死亡に対し error リスナーと exit リスナーが両方発火する
- **THEN** `WorkerDiedResponse` は responses stream へ高々1回だけ流れる

### Requirement: dispose 起因の正常終了を異常終了として扱わない

`TtsIsolate.dispose()` による worker の正常終了は worker 異常終了として扱 SHALL NOT。`dispose()` 実行中は spawn 登録の死亡検知を抑止し、`WorkerDiedResponse` を流 SHALL NOT。

#### Scenario: 正常 dispose では WorkerDiedResponse を流さない

- **WHEN** `dispose()` が呼ばれ、`DisposeMessage` を受けた worker が receivePort を閉じて正常終了する
- **THEN** spawn 登録の exit リスナーが発火しても `WorkerDiedResponse` は responses stream へ流れない

### Requirement: worker 死亡時に待機中の操作を決定論的にエラー解決する

`TtsSession` は、待機中の操作（`ensureModelLoaded()` / `synthesize()`）の処理中に `WorkerDiedResponse` を受け取った場合、対応する完了待ちを**決定論的に**解決 SHALL し、無限ハングを起こ SHALL NOT。`ensureModelLoaded()` は `false`、`synthesize()` は `null` を返 SHALL し、失敗理由を警告ログへ記録 SHALL する。

#### Scenario: 合成待ち中に worker が死ぬ

- **WHEN** `synthesize()` がレスポンス待ちの間に `WorkerDiedResponse` が responses stream へ流れる
- **THEN** `synthesize()` は無限に待たず `null` を返し、失敗理由が警告ログへ記録される

#### Scenario: モデルロード待ち中に worker が死ぬ

- **WHEN** `ensureModelLoaded()` がレスポンス待ちの間に `WorkerDiedResponse` が responses stream へ流れる
- **THEN** `ensureModelLoaded()` は無限に待たず `false` を返し、失敗理由が警告ログへ記録される

### Requirement: モデルロードのタイムアウト

`TtsSession` は、`ensureModelLoaded()` の完了待ちに対し注入可能なタイムアウトを適用 SHALL する。タイムアウト経過時は警告ログを記録し `false` を返 SHALL す。これにより worker が生存したまま native ロードで停止した稀なケースでも完了待ちを解放 SHALL する。

#### Scenario: モデルロードがタイムアウトする

- **WHEN** worker が `ModelLoadedResponse` も `WorkerDiedResponse` も返さないまま、注入されたタイムアウトが経過する
- **THEN** `ensureModelLoaded()` は `false` を返し、タイムアウトを示す警告ログが記録される

#### Scenario: タイムアウト前にロード成功すれば結果を返す

- **WHEN** 注入されたタイムアウト経過前に `ModelLoadedResponse(success: true)` が届く
- **THEN** `ensureModelLoaded()` はタイムアウトせず `true` を返す
