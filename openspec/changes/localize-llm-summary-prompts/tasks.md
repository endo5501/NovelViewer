## 1. LlmPromptBuilder の多言語化（TDD）

- [x] 1.1 `llm_prompt_builder_test.dart` に、`buildFactExtractionPrompt` が `language`（ja/en/zh）を受け取り、各言語で出力するよう指示する文を含むことを検証するテストを追加（失敗を確認）
- [x] 1.2 同テストに、固有名詞を原語のまま維持する指示文を含むことを検証するケースを追加（失敗を確認）
- [x] 1.3 `buildFinalSummaryPrompt` についても 1.1・1.2 と同等のテストを追加（失敗を確認）
- [x] 1.4 ここまでのテスト（言語指示・固有名詞維持）が正しく失敗することを確認してコミット
- [x] 1.5 `LlmPromptBuilder` の両メソッドに `language` パラメータを追加し、出力言語指示と固有名詞維持指示を組み込んで実装（テストをパスさせる）

## 2. パイプライン／サービスへの language 配線（TDD）

- [x] 2.1 `llm_summary_pipeline_*_test.dart` に、`LlmSummaryPipeline` が受け取った `language` を Stage1・Stage2 両プロンプトへ伝播することを検証するテストを追加（失敗を確認）
- [x] 2.2 `LlmSummaryPipeline` に `language` を追加し、`buildFactExtractionPrompt`／`buildFinalSummaryPrompt` 呼び出しへ伝播（テストをパスさせる）
- [x] 2.3 `llm_summary_service_*_test.dart` に、`generateSummary(language:)` がパイプラインへ `language` を渡すことを検証するテストを追加（失敗を確認）
- [x] 2.4 `LlmSummaryService.generateSummary` に `language` を追加しパイプラインへ伝播（テストをパスさせる）

## 3. AnalysisRunner から locale の取得・受け渡し

- [ ] 3.1 `AnalysisRunner` で `localeProvider` の言語コードを読み取り `generateSummary(language:)` へ渡す実装を追加
- [ ] 3.2 既存の解析フローテストが回帰しないことを確認（必要に応じて runner レベルのテストを追加・更新）

## 4. キャッシュ非変更の確認

- [ ] 4.1 `fact_cache` / `word_summaries` のキー・スキーマが変更されていないこと、`FactCacheRepository.currentPromptVersion` が変更されていないことをコードで確認
- [ ] 4.2 言語を跨いでもキャッシュキーに言語が混入しないこと（仕様の運用どおり手動再生成で解消する想定）をテストまたはレビューで確認

## 5. 最終確認

- [ ] 5.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 5.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 5.3 `fvm flutter analyze`でリントを実行
- [ ] 5.4 `fvm flutter test`でテストを実行
