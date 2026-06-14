## Why

TDD駆動の本リポジトリにおいて、本番から一切参照されない「死にコード」と、それを緑のまま維持する「偽カバレッジテスト」が複数残っている（TECH_DEBT_AUDIT.md の F133 / F146 / F164）。緑のテストが実際には何も守っていない状態は、テスト資産全体の信頼性を毀損する。特に `DownloadService.fetchPage` は、再利用されると charset 誤判定による文字化けや Cloudflare 403 を引き起こす「罠」で、参照ゼロのまま放置すると将来の誤用を招く。振る舞いを一切変えずに、これらを除去してテストの信号品質を回復する。

## What Changes

確実に本番未参照と検証できた死にコードのみを、対応するテスト・spec とともに削除する（**振る舞い変更ゼロ・削除主体**）。

- **F164a（最優先・罠）**: `DownloadService.fetchPage`（`download_service.dart`）を削除。参照ゼロ。現役の `_fetchPageResponse` は残す。
- **F164b**: `hitTestCharIndex`（`vertical_text_layout.dart`）と専用テスト群を削除。現役の `hitTestCharIndexFromRegions` は残す。テストは廃止済みグリッド幾何を assert しており誤った安心感を与えている。
- **F164c**: `detectSwipe`（`swipe_detection.dart`）と専用テストを削除。現役の `detectSwipeFromDrag` は残す。
- **F164d**: `buildPlainText`（`ruby_text_parser.dart`）と専用テストを削除。本番は等価な `_concatenatedBaseText`（`ruby_text_builder.dart`、現役）を使用している。
- **F133**: `LlmSummaryPipeline.generate()` と、それをピン留めする `llm_summary_pipeline_test.dart` のテスト群を削除。本番は `extractFileFacts` / `summarizeFromFacts` のみ使用。`generate()` 固有の検証（再帰的 fact 抽出の停止条件、進捗通知ラウンド）のうち、現役メソッドのテスト（`llm_summary_pipeline_per_file_test.dart`）で未カバーのものは `summarizeFromFacts` 経由のテストへ移植する。共有ヘルパー（`_extractFactsRecursive` / `_isolatedNotifier` / `_parseSummaryResponse`）は現役のため残す。
- **F146**: `TtsStoredPlayerController` クラス（`tts_stored_player_controller.dart`）と専用テスト `tts_stored_player_controller_test.dart`（約324行）を削除。本番では生成ゼロで、保存音声再生は統合コントローラ `TtsStreamingController` が担う。`tts-stored-playback` spec のうち**死クラスを名指しする箇所のみ**を更新する（振る舞い要件自体は現役のため維持）。
- 上記に合わせて TECH_DEBT_AUDIT.md の F133 / F146 / F164 を解決済みに更新し、監査が陳腐化していた項目（下記 Non-Goal）を注記する。

### Non-Goals（今回は対象外。監査リストが陳腐化/現役のため明示的に除外）

- `getGeneratedSegmentCount`: 監査では「テストのみ参照」とあるが、現在は `tts_streaming_controller.dart:152` で**本番使用中**。削除しない。
- `computeLineStartOffsets`: 現役関数 `measureCharOffsetY` のテストで**オラクル（期待値計算）**として使用されており、偽カバレッジではない。残す。
- `getSegmentCount`: 現役の `tts_edit_controller` テストでオラクルとして使用される自然な repository API。残す。
- `isConfigured`（`llm_config.dart`）/ `voice_recording_service.isRecording` / `TtsEditSegmentsNotifier.updateSegment`: 本番未参照だが無害な自然 API で、一部は現役テストのオラクル。価値が低く摩擦があるため今回は見送り。

## Capabilities

### New Capabilities

- （なし）

### Modified Capabilities

- `tts-stored-playback`: 「Audio buffer drain before stop on last segment」要件が削除対象クラス `TtsStoredPlayerController` を名指ししている箇所を、実所有者の表現へ修正（または死クラス固有シナリオの除去）。バッファドレインが共有 `SegmentPlayer` に存在するという本質的制約は不変。

## Impact

- **削除コード（lib）**: `tts_stored_player_controller.dart`（全体）、`download_service.dart`（`fetchPage`）、`vertical_text_layout.dart`（`hitTestCharIndex`）、`swipe_detection.dart`（`detectSwipe`）、`ruby_text_parser.dart`（`buildPlainText`）、`llm_summary_pipeline.dart`（`generate()`）。
- **削除/縮小テスト**: `tts_stored_player_controller_test.dart`（全体）、`vertical_text_layout_test.dart`・`swipe_detection_test.dart`・`ruby_text_parser_test.dart`・`llm_summary_pipeline_test.dart`（該当グループ）。
- **spec**: `openspec/specs/tts-stored-playback/spec.md`（死クラス名指し箇所のみ）。
- **ドキュメント**: `TECH_DEBT_AUDIT.md`。
- **振る舞い・公開UI・DBスキーマ**: 変更なし。`fvm flutter analyze` 指摘ゼロ・全テスト green を維持することが完了条件。
