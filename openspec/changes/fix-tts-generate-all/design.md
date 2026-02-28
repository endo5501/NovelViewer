## Context

読み上げ編集画面（`TtsEditDialog`）の「全生成」機能には2つの問題がある。

**問題1: 中断が実効的でない**

現在の中断処理は `_cancelled` フラグを `true` に設定し、`generateAllUngenerated()` のループ内で次のセグメント開始前にチェックする方式。しかし、現在実行中の `_synthesize()` は Isolate 内の `engine.synthesize()` が完了するまで await し続ける。中断ボタン押下時に UI は即座に idle 状態に遷移するが、バックグラウンドの Isolate は合成を続行している。

さらに、`_generateAll()` メソッドは `await controller.generateAllUngenerated()` を待機しているため、中断後もこの Future が完了するまでリソースを保持し続ける。

**問題2: 生成中のセグメント表示が行レベルで機能していない**

`generateAllUngenerated()` 実行中に `ttsEditGeneratingIndexProvider` が各セグメントのインデックスに設定されていない。`onSegmentGenerated` コールバックは生成完了時にインデックスを `null` にリセットするが、生成開始時にインデックスを設定する仕組みがない。結果として、ツールバーのグローバルスピナーのみが表示され、どのセグメントが処理中かが分からない。

## Goals / Non-Goals

**Goals:**

- 中断操作で実際にバックグラウンドの TTS 合成を即座に停止する
- 中断後も同じダイアログ内で引き続き単体生成・全生成を使用できる
- 生成中のセグメントを行のステータスアイコン（スピナー）で表示する
- ツールバーの `CircularProgressIndicator` を廃止する（中断ボタンは維持）

**Non-Goals:**

- ネイティブ TTS エンジン（C++側）へのキャンセル API 追加（Isolate ごと停止する方式で対応）
- 全生成の進捗バー表示（行レベルのスピナーで十分）
- 並列生成の導入（現在のシーケンシャル生成を維持）

## Decisions

### Decision 1: Isolate dispose による中断

**選択**: 中断時に `TtsIsolate.dispose()` を呼び出して Isolate を強制停止する。

**理由**: ネイティブ TTS エンジン（`engine.synthesize()`）には途中停止の API がない。フラグベースのキャンセルでは Isolate 内の合成完了を待つ必要がある。`TtsIsolate.dispose()` は既にタイムアウト付きの graceful shutdown + force kill ロジックを備えている（`_disposeTimeout = 2秒`）。

**代替案**:
- Isolate にキャンセルメッセージを送る方式 → ネイティブ合成処理がブロッキングのため、メッセージを受け取れない
- フラグのみの改善 → 現在の1セグメント完了待ちを解消できない

### Decision 2: Isolate の再作成方式

**選択**: `TtsEditController` の `_ttsIsolate` フィールドを非 final にし、`cancel()` 内で dispose 後に新しいインスタンスを作成する。`_modelLoaded` を `false` にリセットし、次回の `generateSegment()` 呼び出し時に `_ensureModelLoaded()` で新しい Isolate を spawn + モデルロードする。

**理由**: `TtsIsolate.dispose()` は内部の `StreamController` を close するため、同一インスタンスの再利用は不可能。新インスタンスの作成が必要。既存の `_ensureModelLoaded()` の仕組みがそのまま活用でき、変更範囲が最小限になる。

**実装詳細**:
```
cancel() {
  _cancelled = true;
  _subscription?.cancel();
  _ttsIsolate.dispose();          // Isolate を停止
  _ttsIsolate = TtsIsolate();     // 新インスタンス作成
  _modelLoaded = false;           // 次回使用時に再ロード
  _subscription = null;
}
```

### Decision 3: generateAllUngenerated の _synthesize 中断対応

**選択**: `_synthesize()` の `Completer` を `cancel()` 内でエラー完了させることで、await を即座に解除する。

**理由**: `generateAllUngenerated()` は `await generateSegment()` → `await _synthesize()` → `await completer.future` の連鎖で待機している。Isolate を dispose しても Completer が完了しなければ `_generateAll()` の await は解除されない。Completer をフィールドに保持し、cancel 時にエラーで完了させることで、`_generateAll()` が即座に戻れるようにする。

**実装詳細**:
- `_synthesize()` の Completer をインスタンスフィールド `_activeSynthesisCompleter` として保持
- `cancel()` 内で `_activeSynthesisCompleter?.completeError('cancelled')` を呼び出す
- `_synthesize()` 内で try-catch してキャンセル時は `null` を返す
- `generateSegment()` が `null` を受け取ると `false` を返し、`generateAllUngenerated()` のループが `break` する

### Decision 4: セグメント生成開始コールバックの追加

**選択**: `generateAllUngenerated()` に `onSegmentStart` コールバックパラメータを追加。各セグメントの生成開始前にセグメントインデックスを通知する。（`playAll()` の `onSegmentStart` と同じパターン）

**理由**: 現在は生成完了時の `onSegmentGenerated` コールバックのみ。生成開始時にインデックスを通知する仕組みがないため、UI 側で `ttsEditGeneratingIndexProvider` を設定できない。

**実装詳細**:
```
Future<void> generateAllUngenerated({
  required String modelDir,
  String? globalRefWavPath,
  void Function(int segmentIndex)? onSegmentStart,  // 追加
}) async {
  for (var idx ...) {
    if (_cancelled) break;
    onSegmentStart?.call(segmentIndex);  // 生成開始前に通知
    final success = await generateSegment(...);
    ...
  }
}
```

UI 側の呼び出し:
```
await controller.generateAllUngenerated(
  modelDir: modelDir,
  globalRefWavPath: globalRefWavPath,
  onSegmentStart: (index) {
    if (mounted) {
      ref.read(ttsEditGeneratingIndexProvider.notifier).set(index);
    }
  },
);
```

### Decision 5: ツールバー UI の変更

**選択**: ツールバーから `CircularProgressIndicator`（16×16）を削除し、中断ボタンのみ残す。全生成ボタンの位置に中断ボタンを表示する（全生成ボタンは非表示にする）。

**理由**: セグメント行のステータスアイコンにスピナーが表示されるため、ツールバーのグローバルスピナーは冗長。中断ボタンはツールバーに残すことで操作性を維持する。

**実装詳細**:
- `isGenerating` 時: 全生成ボタンを中断ボタンに置き換え
- ツールバー右端の `CircularProgressIndicator` + `Spacer` を削除

## Risks / Trade-offs

- **[リスク] Isolate 再作成時のモデルロード時間**: 中断後に再生成を開始する際、モデルの再ロードが必要（数秒）。→ 許容範囲。中断操作自体が稀であり、ユーザーは意図的に中断しているため待機を受け入れられる。
- **[リスク] Isolate dispose のタイムアウト**: ネイティブ合成が長時間ブロックしている場合、graceful shutdown が2秒タイムアウトして force kill になる。→ 既存の `TtsIsolate.dispose()` のロジックで適切に処理済み。
- **[トレードオフ] cancel() の非同期化**: 現在の `cancel()` は `_cancelled = true` のみで即座に完了するが、新実装では Isolate dispose を含むため非同期になる。→ UI 側は既に `await _controller?.cancel()` として呼び出しており、影響なし。
