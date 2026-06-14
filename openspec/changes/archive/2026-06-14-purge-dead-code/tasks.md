## 1. 事前検証（削除前のベースライン）

- [x] 1.1 `fvm flutter test` と `fvm flutter analyze` を実行し、削除前の全 green / 指摘ゼロを記録（回帰の基準点）→ 2165 tests passed / No issues found
- [x] 1.2 削除対象6シンボルそれぞれを `\bsymbol\b` 境界照合で lib 全体検索し、「定義 + 自身の専用テストのみ」を最終確認（現役の兄弟シンボル `hitTestCharIndexFromRegions` / `detectSwipeFromDrag` / `_concatenatedBaseText` / `_fetchPageResponse` / `getGeneratedSegmentCount` を保持対象として明示）

## 2. F164a — fetchPage 削除（最優先・罠）

- [x] 2.1 `lib/features/text_download/data/download_service.dart` の `fetchPage` メソッドを削除（`_fetchPageResponse` は残す）
- [x] 2.2 `fvm flutter analyze` で未解決参照ゼロを確認

## 3. F164b/c/d — text_viewer 系の死関数削除

- [x] 3.1 `lib/features/text_viewer/data/vertical_text_layout.dart` の `hitTestCharIndex` を削除（`hitTestCharIndexFromRegions` は残す）
- [x] 3.2 `test/features/text_viewer/data/vertical_text_layout_test.dart` の `hitTestCharIndex` テストグループ（廃止済みグリッド幾何 assert）を削除
- [x] 3.3 `lib/features/text_viewer/data/swipe_detection.dart` の `detectSwipe` を削除（`detectSwipeFromDrag` は残す）
- [x] 3.4 `test/features/text_viewer/data/swipe_detection_test.dart` の `detectSwipe` テストを削除
- [x] 3.5 `lib/features/text_viewer/data/ruby_text_parser.dart` の `buildPlainText` を削除（本番は等価な `_concatenatedBaseText` を使用）
- [x] 3.6 `test/features/text_viewer/ruby_text_parser_test.dart` の `buildPlainText` テストグループを削除
- [x] 3.7 `fvm flutter analyze` で未解決参照ゼロを確認

## 4. F133 — LlmSummaryPipeline.generate() 削除

- [x] 4.1 `test/features/llm_summary/data/llm_summary_pipeline_test.dart` と `llm_summary_pipeline_per_file_test.dart` を突き合わせ、`generate()` テスト固有の検証（再帰 fact 抽出の停止条件・進捗通知ラウンド）のうち `summarizeFromFacts`/`extractFileFacts` テストで未カバーのものを洗い出す → 7件のギャップ（A再帰上限/B無進捗停止/C-D F132/E非JSON fallback/Fコードフェンス/G onProgress隔離）を特定。round=1発火は新アーキでは呼び出し側責務のため破棄
- [x] 4.2 未カバーの固有 assert を `summarizeFromFacts` 経由のテストへ移植（カバー済みなら移植不要）→ `llm_summary_pipeline_per_file_test.dart` に「shared-helper behavior」グループ7本を追加
- [x] 4.3 `lib/features/llm_summary/data/llm_summary_pipeline.dart` の `generate()` メソッドを削除（`_extractFactsRecursive` / `_isolatedNotifier` / `_parseSummaryResponse` は現役のため残す）
- [x] 4.4 `llm_summary_pipeline_test.dart` の `generate()` 依存テスト群を削除（ファイル全体が generate() 専用のため削除）
- [x] 4.5 `fvm flutter analyze` で未解決参照ゼロ、`fvm flutter test` で llm_summary 関連が green を確認

## 5. F146 — TtsStoredPlayerController 削除 + spec 更新

- [x] 5.1 `lib/features/tts/data/tts_stored_player_controller.dart` を削除
- [x] 5.2 `test/features/tts/data/tts_stored_player_controller_test.dart`（約324行）を削除
- [x] 5.3 `tts_stored_player_controller.dart` のみが import していたシンボルが他で孤立しないことを確認（`tts_playback_controller` / `segment_player` / `tts_audio_repository` は現役のため存続）→ analyze 指摘ゼロで確認
- [x] 5.4 `openspec/specs/tts-stored-playback/spec.md` の「Audio buffer drain before stop on last segment」要件内の `TtsStoredPlayerController` 名指し2箇所を `TtsStreamingController` に更新（本変更の spec delta で表現。live spec はアーカイブ時に同期）
- [x] 5.5 `fvm flutter analyze` で未解決参照ゼロを確認

## 6. ドキュメント同期

- [x] 6.1 `TECH_DEBT_AUDIT.md` の F133 / F146 を解決済みに、F164 を一部解決（fetchPage 含む4シンボル解決）に更新
- [x] 6.2 監査の陳腐化項目を注記（`getGeneratedSegmentCount` は本番使用中、`computeLineStartOffsets`/`getSegmentCount` は現役テストのオラクル、`isConfigured`/`isRecording`/`updateSegment` は Non-Goal）

## 7. 最終確認

- [x] 7.1 code-reviewスキルを使用してコードレビューを実施 → 2エージェント（移植テスト正当性 / 削除参照監査）とも0件
- [x] 7.2 codexスキルを使用して現在開発中のコードレビューを実施 → 指摘なし
- [x] 7.3 `fvm flutter analyze`でリントを実行 → No issues found
- [x] 7.4 `fvm flutter test`でテストを実行 → 2127 passed / 1 skipped（baseline 2165 から死コードテスト削除分を反映）
