## Why

用語要約機能は、表示言語を英語・中国語に設定しても説明が日本語で表示される。原因は、LLMプロンプト（`LlmPromptBuilder`）が指示文・出力フォーマットともに日本語でハードコードされており、表示言語設定（`localeProvider`）がプロンプト生成まで一切伝播していないためである。LLMはプロンプト言語に引きずられて日本語で応答する。多言語UIを提供している以上、要約も表示言語に追従すべきである。

## What Changes

- Stage1（事実抽出）・Stage2（最終要約）の両プロンプトに、UI表示言語（ja/en/zh）で出力するよう指示を追加する。
- 固有名詞（作品中の人名・地名など）は翻訳せず原語のまま維持するよう、両プロンプトで明示する。
- `localeProvider` の言語コードを `AnalysisRunner` → `LlmSummaryService` → `LlmSummaryPipeline` → `LlmPromptBuilder` へ配線する。
- 事実抽出を日本語固定とする前提を撤廃し、Stage1・Stage2の両方をUI表示言語に揃える（本文が日本語とは限らず、英語・中国語のテキストも配置されうるため）。
- キャッシュ（`fact_cache`／`word_summaries`）はスキーマを変更しない。言語カラムやマイグレーションは追加しない。言語切替で既存キャッシュと表示言語が食い違った場合は、既存の単語削除UI（`deleteAllForWord`）で削除し再生成する運用とする。
- `FactCacheRepository.currentPromptVersion` はbumpしない（既存fact_cacheの一括無効化は行わない）。

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `llm-summary-pipeline`: 「Fact extraction prompt construction」「Final summary prompt construction」の2要件に、出力言語をUI表示言語に追従させ固有名詞を原語のまま維持するという振る舞いを追加する。

## Impact

- `lib/features/llm_summary/data/llm_prompt_builder.dart`: 両プロンプトビルダーに `language` パラメータと出力言語・固有名詞維持の指示を追加。
- `lib/features/llm_summary/data/llm_summary_pipeline.dart`: `language` を受け取り両ビルダー呼び出しへ伝播。
- `lib/features/llm_summary/data/llm_summary_service.dart`: `generateSummary` に `language` を追加しパイプラインへ伝播。
- `lib/features/llm_summary/presentation/analysis_runner.dart`: `localeProvider` から言語コードを取得し `generateSummary` へ渡す。
- キャッシュ層（`fact_cache_repository.dart` / `llm_summary_repository.dart`）はスキーマ・キー変更なし。
- 既存テスト（`llm_prompt_builder_test.dart`, `llm_summary_pipeline_*_test.dart`, `llm_summary_service_*_test.dart`）の更新と多言語ケース追加。
