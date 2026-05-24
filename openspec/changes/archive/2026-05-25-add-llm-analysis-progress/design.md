## Context

LLM 解析 (`LlmSummaryPipeline.generate`) は、長さに応じて以下を可変回数実行する：

1. fact 抽出（depth 0）— chunk 分割後の各 chunk に対して 1 回ずつ LLM 呼び出し。
2. 絞り込み（depth 1..5）— 直前のフェーズの出力がまだ大きい場合、再度 chunk 分割して LLM 呼び出し。
3. 最終要約 — 1 回の LLM 呼び出し。

現状の UI は `_AnalysisModal` (`lib/features/llm_summary/presentation/analysis_runner.dart:99`) が `CircularProgressIndicator` + 「LLM 解析中…」固定テキストを出すだけで、進捗の手がかりは皆無。

`LlmClient.generate` は同期的に `Future<String>` を返す single-shot API であり、ストリーミング応答には対応していない（`OllamaClient` は `stream: false`、`OpenAiCompatibleClient` は chat completions の単発レスポンス）。よって本 change の進捗粒度は「LLM 呼び出し回数」が自然な単位となる。

## Goals / Non-Goals

**Goals:**

- ユーザがモーダルを見たときに「今何をしていて、おおよそ何ステップ目か」が分かること。
- 既存の Pipeline / Service / Runner の責務分離を壊さないこと。
- 既存の `LlmClient` 抽象（`generate(prompt) -> Future<String>`）を変更しないこと（OpenAI/Ollama 両クライアントへの波及を避ける）。
- 既存テスト（`llm_summary_pipeline_test.dart` 他）に対する破壊的変更を最小化すること。

**Non-Goals:**

- トークン単位のストリーミング進捗（プログレスバーが滑らかに動く UX）。これは `LlmClient` API 自体の作り変えが必要になり、別 change の検討材料とする。
- 完全に正確な ETA 表示。再帰深化で分母が増えることを許容する。
- キャンセル機能。別 change で扱う。
- 検索フェーズ（`searchService.searchWithContext`）の進捗。十分高速なので対象外。

## Decisions

### 進捗の型は sealed class（`AnalysisProgress`）

`lib/features/llm_summary/domain/analysis_progress.dart` に sealed class を定義：

```dart
sealed class AnalysisProgress { const AnalysisProgress(); }

class AnalysisExtractingFacts extends AnalysisProgress {
  final int current;   // 1-indexed, current chunk
  final int total;     // chunks in this round
  final int round;     // 1 = 初回 (旧 depth 0), 2+ = 絞り込み N 周目
  const AnalysisExtractingFacts({
    required this.current,
    required this.total,
    required this.round,
  });
}

class AnalysisGeneratingFinalSummary extends AnalysisProgress {
  const AnalysisGeneratingFinalSummary();
}
```

検索フェーズ用のイベントは作らない（Non-Goals）。

**代替案：** 単純な `String` ラベル + `double progress` でも UI は実現できるが、UI 側の文字列組み立てが Pipeline 側に漏れるため不採用。`AnalysisProgress` を中間表現として持てば l10n は presentation 層で完結する。

### Pipeline には `void Function(AnalysisProgress)? onProgress` を追加

```dart
Future<String> generate({
  required String word,
  required List<String> contexts,
  void Function(AnalysisProgress progress)? onProgress,  // ← 新規・省略可
}) async { ... }
```

**Stream<AnalysisProgress> を返さない理由：**

- 戻り値の型を変えると既存呼び出し全箇所と全テストが破壊される。
- 単方向通知のみで back-pressure 不要なので、Stream のオーバーヘッドは過剰。
- コールバック方式なら null 既定で既存呼び出しは無影響。

`_extractFactsRecursive` に `round` を渡し、各 chunk 処理直前に `onProgress?.call(AnalysisExtractingFacts(...))`。再帰呼び出しは `round + 1` で進める。最終要約呼び出し直前に `onProgress?.call(AnalysisGeneratingFinalSummary())`。

### Service は進捗を素通しする

`LlmSummaryService.generateSummary` にも同じ `onProgress` を追加し、Pipeline へそのまま渡す。Service 自身は新しいイベントを発行しない（filter / 検索は進捗対象外、release は内部処理）。

### Modal は `ValueListenable<AnalysisProgress?>` を購読

`DefaultAnalysisRunner.run` 内で `ValueNotifier<AnalysisProgress?>` を 1 つ生成し、`_AnalysisModal` にコンストラクタで渡す。Pipeline からのコールバックで `notifier.value = progress` を更新。Modal は `ValueListenableBuilder` で再描画。

**Riverpod provider にしない理由：** モーダルは 1 解析セッションに 1 つしか存在せず、グローバルに観測できる必要もない。`ValueNotifier` を Runner ローカルで握る方が解析セッションのライフサイクルと一致しモデルが単純。

### ローカライズキー

`app_*.arb` に追加：

- `llmAnalysis_extractingFacts` — 例（ja）: `"情報を抽出中 ({current} / {total})"`、プレースホルダ `{current}`, `{total}`。
- `llmAnalysis_refiningRound` — 例（ja）: `"絞り込み {round} 周目 ({current} / {total})"`、プレースホルダ `{round}`, `{current}`, `{total}`。
- `llmAnalysis_generatingFinal` — 例（ja）: `"最終要約を生成中…"`。
- 既存の `llmAnalysis_inProgress` は初期状態（イベント未受信時）にのみ使い続ける。

英中も同等の文言を用意する。

### `round` の数え方

- 旧 `depth == 0`（初回 fact 抽出）→ `round = 1`、UI は `extractingFacts` を表示。
- 旧 `depth >= 1`（再帰絞り込み）→ `round = depth + 1`、UI は `refiningRound` を表示。
- これにより「絞り込み 2 周目」=「初回抽出後の最初の再集約」となり、内部 `depth` の 0-index を UI に漏らさない。

## Risks / Trade-offs

- **分母が途中で増える** → 再帰深化に入ると `total` がリセットされ、新しい round 表示に切り替わる。`refiningRound` ラベルで「ラウンドが変わった」ことを明示することで、ユーザが「数字が逆行した」と感じにくいよう緩和。
- **新規 sealed class の他 capability 流用** → 将来キャンセル change や別 LLM 機能でも使えるよう汎用名 `AnalysisProgress` にしたが、現時点では `llm-summary-pipeline` 専用。スコープ拡大時はファイル位置を再検討する。
- **テスト追加コスト** → `onProgress` の呼び出し順／回数を検証する pipeline テストと、`ValueNotifier` を注入してモーダルの表示文字列を検証する runner テストを追加する必要がある。逆に、現行モーダルテストは初期状態（イベント未受信）の表示が `inProgress` であることを確認するだけで済む。
- **検索フェーズの暗黙的体感** → 検索フェーズ中はイベントが何も発火しないため、ユーザは依然として初期スピンを見続ける。検索が遅い folder では「進捗が動かない」と誤解される可能性があるが、現状の経験上ほぼ瞬時に終わるため許容する。問題が顕在化したら別 change で `AnalysisSearching` を追加可能。
