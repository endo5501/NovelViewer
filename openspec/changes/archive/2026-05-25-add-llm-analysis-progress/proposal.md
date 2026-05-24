## Why

LLM 解析中はモーダルに無限スピンしか出ておらず、所要時間も「あと何回 LLM を叩くのか」も全く分からない。再帰的な fact 抽出を含むパイプラインは長文小説では数分単位かかることがあり、ユーザは「止まっているのか進行中なのか」を判断できず、解析を信頼して任せることができない。

## What Changes

- `LlmSummaryPipeline.generate` に進捗通知のためのコールバック（または `Stream<AnalysisProgress>` 戻り値）を追加し、次の3種類のイベントを発行する：
  - **fact 抽出フェーズ** — 現在のチャンク番号 / 総数（depth 0）
  - **絞り込みフェーズ** — 「絞り込み N 周目」のラベル付きで current / total（depth 1 以上）
  - **最終要約生成フェーズ**
- `_AnalysisModal` を進捗通知を購読する形に改修し、テキスト表示を「LLM 解析中…」固定から動的なフェーズ＋カウンタ表示に変更する。
- 検索フェーズ（`searchService.searchWithContext`）は十分高速なので進捗表示の対象外とする。
- キャンセル機能は本 change のスコープ外（別 change で扱う）。
- 進捗の精度は完全保証しない：再帰深化により総数（分母）が途中で増えることを許容する。目的は「何をしているか分かる」ことであり、正確な ETA ではない。
- 新規ローカライズ文字列を `app_en.arb` / `app_ja.arb` / `app_zh.arb` に追加。

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `llm-summary-pipeline`: パイプラインは進捗イベントを観測可能にする要件を追加（既存の chunk 分割・recursive aggregation・final summary は変更なし）。
- `llm-summary`: 解析モーダルが進捗イベントを購読してフェーズ／カウンタを表示する要件を追加（既存の解析トリガー・結果保存ロジックは変更なし）。

## Impact

- 影響コード：
  - `lib/features/llm_summary/data/llm_summary_pipeline.dart` — 進捗通知の発行
  - `lib/features/llm_summary/data/llm_summary_service.dart` — Pipeline からの進捗を上位へ中継
  - `lib/features/llm_summary/presentation/analysis_runner.dart` — モーダルへ進捗を渡す配線
  - `lib/features/llm_summary/presentation/analysis_runner.dart` 内の `_AnalysisModal` — 進捗を購読・描画
  - 新規ドメイン型ファイル `lib/features/llm_summary/domain/analysis_progress.dart` を追加（sealed class 想定）
  - `lib/l10n/app_en.arb` / `app_ja.arb` / `app_zh.arb` — 進捗ラベル文字列の追加
- 影響テスト：
  - `test/features/llm_summary/data/llm_summary_pipeline_test.dart` — 進捗通知の発行順を検証
  - `test/features/llm_summary/presentation/analysis_runner_test.dart` — モーダル表示の更新検証
- API 互換性：
  - `LlmSummaryPipeline.generate` のシグネチャに省略可能な進捗パラメータが追加されるが、既存呼び出しは影響を受けない方針とする。
- 依存関係：追加なし（既存の `flutter_riverpod` / `ValueListenable` の枠内で実装可能）。
