## Context

`TtsIsolate`（`lib/features/tts/data/tts_isolate.dart`）は worker isolate を `Isolate.spawn` で起動し、`SendPort` でメッセージを送り、worker からの `TtsIsolateResponse` を `broadcast` stream で配る。`TtsSession`（`tts_session.dart`）は各操作ごとに per-call の `responses.listen` を張り、対応するレスポンス（`ModelLoadedResponse` / `SynthesisResultResponse`）が来たら completer を解決する。

worker entry point（`_isolateEntryPoint`）の `receivePort.listen` 内では LoadModel / Synthesize を try/catch で囲み、**エンジン由来の例外はエラーレスポンスに変換**している。したがって「通常のエンジンエラー」は既にハングしない。

問題は try/catch の**外**で worker が死ぬケース:
- メッセージのデシリアライズ失敗、`listen` コールバック外の uncaught error、OOM、その他 Dart レベルの致命的エラー。
- この場合 worker isolate は終了するが、main 側には何も届かず、待機中の completer が永久未解決 → streaming が "waiting" のまま無限ハング。

現状 `spawn()` には通常運用時の `addErrorListener` / `addOnExitListener` が無い（`dispose()` 内で `addOnExitListener` を使い graceful shutdown を待つコードのみ）。

制約:
- F111（add-db-handle... ではなく fix-tts-abort-use-after-free）で確立した「abort handle はセッション寿命で所有、force-kill 時は free しない」設計を壊さないこと。
- ネイティブ（C/FFI）には触れない。
- streaming controller / edit controller の呼び出し契約（戻り値の意味）を変えないこと。

## Goals / Non-Goals

**Goals:**
- worker isolate の異常終了（uncaught error / 予期しない exit）を通常運用中に検知する。
- 検知時、待機中の `synthesize()` / `ensureModelLoaded()` を**決定論的に**エラー解決し、無限ハングを根絶する。
- 失敗を警告ログに残し、フィールドで診断可能にする。
- TDD で検証可能にする（worker をわざと死なせる注入経路を用意）。

**Non-Goals:**
- worker をクラッシュさせない（クラッシュ予防そのもの）。本変更は「死んでもハングしない」検知・回復に限定。
- 合成（synthesize）への固定タイムアウト導入。長文合成は正当に長時間かかるため、固定値は誤 abort を生む。worker 死亡検知を一次対策とする。
- ネイティブ FFI コードの変更。
- abort / dispose のライフサイクル設計（F111 で確立済み）の再設計。

## Decisions

### 決定1: worker 死亡を broadcast stream 上の新レスポンスとして表現する

`TtsIsolateResponse` の sealed 階層に `WorkerDiedResponse { final String error; }` を追加し、worker 異常終了検知時に `_responseController.add(WorkerDiedResponse(...))` で流す。

- **なぜ**: `TtsSession` は既に per-call で `responses` を listen して completer を解決する構造。死亡シグナルを同じ stream に載せれば、既存リスナーに分岐を1つ足すだけで全ての待機操作（modelLoad / synthesize）を解放できる。新しい通知チャネルを別途作るより一貫性が高い。
- **代替案A（completer を TtsIsolate から直接触る）**: 却下。completer の所有は TtsSession 側にあり、責務が滲む。
- **代替案B（stream を error/close する）**: 却下。broadcast stream を close すると後続の spawn/再利用や他リスナーに影響し、per-call subscription の `onError` 配線も増える。明示的なレスポンス型の方が型安全でテストも素直。

### 決定2: `spawn()` で `addErrorListener` と `addOnExitListener` を登録する

`spawn()` 成功時に、worker isolate に対し:
- `addErrorListener(errorPort.sendPort)` — uncaught error 時に `[errorString, stackString]` を受信。
- `addOnExitListener(exitPort.sendPort)` — isolate 終了時に通知を受信（error を伴わない静かな終了も拾う）。

いずれかが発火したら `_handleWorkerDeath(reason)` を呼ぶ。`_handleWorkerDeath` は冪等（多重発火・二重通知を1回に集約）で、`WorkerDiedResponse` を1度だけ stream に流す。

- **なぜ**: `addErrorListener` が F144 のシナリオ（Dart 例外で worker 死亡）を直接捕捉する。`addOnExitListener` はエラーを伴わない予期しない終了の保険。両方登録するのは監査の推奨（「onError/onExit リスナー」）どおり。

### 決定3: dispose 起因の正常終了を異常終了と誤判定しない

`TtsIsolate` に `bool _disposing` を追加。`dispose()` の先頭で `true` にする。`_handleWorkerDeath` は `if (_disposing) return;` で抑止する。

- **なぜ**: `dispose()` は `DisposeMessage` を送り、worker は `receivePort.close()` して**正常終了**する。この exit は spawn 登録の `addOnExitListener` でも発火するため、抑止しないと正常 dispose のたびに偽の `WorkerDiedResponse` が流れる。
- `dispose()` 内の既存 exit 待ち（`exitPort.first.timeout`）は専用の局所ポートで、spawn 登録分とは別。両立する。

### 決定4: モデルロードにタイムアウト（注入可能）、合成にはタイムアウトを設けない

`TtsSession` コンストラクタに `Duration modelLoadTimeout`（既定: 十分大きい値、例 120 秒）を注入可能にする。`ensureModelLoaded()` の `await completer.future` を `.timeout(...)` でラップし、タイムアウト時は警告ログ＋`false` 解決。

合成側は固定タイムアウトを設けない（Non-Goal）。worker 死亡検知（決定2）が「待機が永久に解けない」根本原因を断つため、合成のハングはこれで解消する。

- **なぜ合成にタイムアウトを設けないか**: 長文セグメントの合成は GPU/CPU により正当に数十秒かかり得る。固定タイムアウトは正当な合成を誤って中断し、しかも worker は生き続けるため desync（completer は null 解決済みなのに worker が後からレスポンスを送る）を生む。worker 死亡という決定論的シグナルの方が安全。
- **なぜモデルロードにはタイムアウトを許すか**: ロードは概ね有界で、注入可能にしておけばテストで短縮でき、「生きているが native ロードで停止」の稀ケースの保険になる。

### 決定5: テストのための worker 死亡注入

`TtsIsolate` の実 isolate を死なせるテストは脆い。代わりに:
- `TtsSession` のテストは fake `TtsIsolate`（`responses` stream を制御可能）を使い、`WorkerDiedResponse` を流して synthesize/ensureModelLoaded が確実に解決することを検証。
- `TtsIsolate` レベルは、worker entry point から意図的に throw させる注入（テスト専用 entrypoint かエラー注入メッセージ）で `addErrorListener` → `WorkerDiedResponse` 経路を検証。実 isolate の自然死を1ケース、可能なら統合テストで担保（DLL self-skip 方針に従う）。

## Risks / Trade-offs

- **[偽の WorkerDiedResponse が正常 dispose 中に流れる]** → 決定3 の `_disposing` フラグで抑止。dispose 順序（フラグ立て→abort→DisposeMessage 送信）をテストで固定。
- **[二重発火（error と exit が両方届く）]** → `_handleWorkerDeath` を冪等化し `WorkerDiedResponse` を1回だけ流す（送信済みフラグ）。
- **[stale な WorkerDiedResponse が次の操作を誤って解決]** → broadcast stream に死亡を流すが、TtsSession の per-call subscription は操作ごとに張り直すため、死亡後に再 spawn しない限り新規待機は発生しない。worker 死亡後は session を dispose/再構築する運用なので stale 解決の窓は狭い。念のため `_handleWorkerDeath` 後は `_sendPort=null` 等で以降の send を無効化する。
- **[合成タイムアウト非導入で「worker 生存・native ハング」は残る]** → 既知の残課題として明記。Isolate.kill すら native を止められないことは dispose のコメントで既出。一次対策は worker 死亡検知で、native 完全ハングは別軸（abort/force-kill）でカバー。
- **[abort handle のライフタイム]** → 死亡検知経路では handle を勝手に free しない。free は従来どおり `dispose()`（worker exit 確認後）に限定し、F111 の UAF 回帰を避ける。

## Open Questions

（解決済み）

## Resolved Decisions

- **worker 死亡検知後の自動復旧（再 spawn / 再ロード）は本変更に含めない**（メンテナ確認済 2026-06-14）。本変更は「ハングせずエラーで返す」までを範囲とし、上位（streaming/edit controller）の再試行 UI は別タスクとする。
- **`modelLoadTimeout` の既定値は 120 秒**で確定（メンテナ確認済 2026-06-14）。
