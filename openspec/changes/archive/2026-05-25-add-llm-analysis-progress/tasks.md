## 1. ドメイン型と l10n の準備

- [x] 1.1 `lib/features/llm_summary/domain/analysis_progress.dart` を新規作成し、`AnalysisProgress` sealed class と `AnalysisExtractingFacts` / `AnalysisGeneratingFinalSummary` の2サブクラスを定義する（コンストラクタ／プロパティのみ、ロジックなし）
- [x] 1.2 `test/features/llm_summary/domain/analysis_progress_test.dart` を新規作成し、`AnalysisExtractingFacts` の各プロパティが渡した値を保持すること、`AnalysisGeneratingFinalSummary` が単一インスタンスとして比較できることを検証するテストを書く
- [x] 1.3 1.2 のテストを `fvm flutter test` で実行し、green になることを確認する
- [x] 1.4 `lib/l10n/app_en.arb` / `app_ja.arb` / `app_zh.arb` に `llmAnalysis_extractingFacts`（プレースホルダ `{current}`, `{total}`）、`llmAnalysis_refiningRound`（プレースホルダ `{round}`, `{current}`, `{total}`）、`llmAnalysis_generatingFinal` の3キーを追加する
- [x] 1.5 `fvm flutter gen-l10n` 相当（または `fvm flutter pub get` でビルド時自動生成）を実行し、`lib/l10n/app_localizations*.dart` が更新されることを確認する

## 2. Pipeline への進捗コールバック追加（テスト先行）

- [x] 2.1 `test/features/llm_summary/data/llm_summary_pipeline_test.dart` に、`onProgress` コールバックを渡したとき、複数チャンクの初回 fact 抽出で `round=1`, `total=N`, `current=1..N` の順に発火することを検証するテストを追加する
- [x] 2.2 同テストに、再帰絞り込みが発生したとき `round=2` 以降が発火し、各 round 内で `current` が 1 から `total` まで進むことを検証するテストを追加する
- [x] 2.3 同テストに、最終要約呼び出し直前に `AnalysisGeneratingFinalSummary` が 1 回だけ発火することを検証するテストを追加する
- [x] 2.4 同テストに、`contexts` が空のときも `AnalysisGeneratingFinalSummary` が 1 回発火することを検証するテストを追加する
- [x] 2.5 同テストに、`onProgress` を渡さない既存呼び出しが従来通りの結果文字列を返すことを検証するテストを追加する
- [x] 2.6 2.1-2.5 のテストが現実装で失敗することを `fvm flutter test` で確認し、コミットする
- [x] 2.7 `lib/features/llm_summary/data/llm_summary_pipeline.dart` の `generate` に `void Function(AnalysisProgress)? onProgress` パラメータを追加する
- [x] 2.8 `_extractFactsRecursive` に `round` パラメータを追加し、各 chunk 処理直前に `onProgress?.call(AnalysisExtractingFacts(...))` を発火するよう実装する（再帰時は `round + 1`）
- [x] 2.9 最終要約 LLM 呼び出し直前に `onProgress?.call(AnalysisGeneratingFinalSummary())` を発火するよう実装する
- [x] 2.10 `fvm flutter test test/features/llm_summary/data/llm_summary_pipeline_test.dart` を実行し、2.1-2.5 のテストが green になることを確認する

## 3. Service の進捗パススルー（テスト先行）

- [x] 3.1 `test/features/llm_summary/data/llm_summary_service_test.dart` に、`generateSummary` に `onProgress` を渡したとき、Pipeline から受けたイベントがそのままコールバックに流れることを検証するテストを追加する（fake LlmClient を使い、最低 1 イベントの流れを確認）
- [x] 3.2 3.1 のテストが失敗することを `fvm flutter test` で確認する
- [x] 3.3 `lib/features/llm_summary/data/llm_summary_service.dart` の `generateSummary` に `void Function(AnalysisProgress)? onProgress` パラメータを追加し、`LlmSummaryPipeline.generate` にそのまま渡す
- [x] 3.4 `fvm flutter test test/features/llm_summary/data/llm_summary_service_test.dart` を実行し、3.1 のテストが green になることを確認する

## 4. Runner と Modal の進捗表示（テスト先行）

- [x] 4.1 `test/features/llm_summary/presentation/analysis_runner_test.dart` に、初期状態（イベント未受信）で `llmAnalysis_inProgress` の文言が表示されることを検証するテストを追加する
- [x] 4.2 同テストに、`AnalysisExtractingFacts(round=1, current=2, total=5)` を `ValueNotifier` に流したとき `llmAnalysis_extractingFacts` の文言（"情報を抽出中 (2 / 5)" 相当）が表示されることを検証するテストを追加する
- [x] 4.3 同テストに、`AnalysisExtractingFacts(round=3, current=1, total=2)` を流したとき `llmAnalysis_refiningRound` の文言（"絞り込み 3 周目 (1 / 2)" 相当）が表示されることを検証するテストを追加する
- [x] 4.4 同テストに、`AnalysisGeneratingFinalSummary()` を流したとき `llmAnalysis_generatingFinal` の文言が表示されることを検証するテストを追加する
- [x] 4.5 同テストに、複数イベントを連続で流してもダイアログが再 push されず同一 route の中身だけが更新されることを検証するテストを追加する
- [x] 4.6 4.1-4.5 のテストが失敗することを `fvm flutter test` で確認する
- [x] 4.7 `lib/features/llm_summary/presentation/analysis_runner.dart` の `_AnalysisModal` を改修し、`ValueListenable<AnalysisProgress?>` を受け取って `ValueListenableBuilder` で再描画する形にする
- [x] 4.8 `DefaultAnalysisRunner.run` 内で `ValueNotifier<AnalysisProgress?>` を生成し、Modal に注入し、`service.generateSummary` に `onProgress: (p) => notifier.value = p` を渡す
- [x] 4.9 解析セッション終了後（成功・失敗・finally のいずれでも）に `notifier.dispose()` を呼ぶよう配線する
- [x] 4.10 `fvm flutter test test/features/llm_summary/presentation/analysis_runner_test.dart` を実行し、4.1-4.5 のテストが green になることを確認する

## 5. 最終確認

- [x] 5.1 code-reviewスキルを使用してコードレビューを実施
- [x] 5.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 5.3 `fvm flutter analyze`でリントを実行
- [x] 5.4 `fvm flutter test`でテストを実行
