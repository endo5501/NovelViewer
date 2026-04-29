## Why

`lib/features/text_viewer/presentation/text_viewer_panel.dart` は 900 LOC、6 ヶ月で 44 commits — リポジトリ全体で**最も churn が高い**ファイル。1 つの `State` クラスに次の 7 つの concerns が同居している:

1. テキスト内容のレンダリング (horizontal/vertical mode 切替)
2. TTS streaming controller のライフタイム管理
3. スクロール / 行追跡
4. 音声状態のポーリング (Sprint 2 で `FutureProvider` 化された前提)
5. ダイアログ起動 (rename, edit 等)
6. MP3 export
7. クリップボード操作

これらが `TtsAudioState × TtsPlaybackState × isWaiting × engineType` の状態マシンを inline switch で扱い、panel-level integration テスト (F011) は無いため、状態遷移の regression は手動 QA でしか拾えない (F005, F011)。

加えて、F028/F029/F046/F051 がこの panel 周辺に集中している:
- **F028**: `_withTtsControls(...)` の同型 4 引数を named にする → 解体で消滅
- **F029**: `build` 内での state 変更 (`_lastViewedFilePath` の `addPostFrameCallback`) を `ref.listen` に移す
- **F046**: `ProviderScope.containerOf(context)` で `TtsStreamingController` に長寿命 container を渡す anti-pattern を `Reader` 関数型に置き換え
- **F051**: `_segmentsCache` の per-widget instance キャッシュを Riverpod provider 化、コンテンツハッシュキャッシュ

これは Sprint 5 = 計画全体の最終 sprint。終了時に F001〜F058 すべての処理状況を tasks.md に明記する。

## What Changes

### Phase A — Panel-level integration test (F011)
- `test/features/text_viewer/presentation/text_viewer_panel_test.dart` を新規追加
- 状態遷移の網羅: `none → generating → ready → playing → paused → stopped` × `Qwen3 / Piper`
- fake `TtsAudioPlayer` / `TtsIsolate` で状態マシンを駆動 (Sprint 3 の `bufferDrainDelay: Duration.zero` を活用)
- 各遷移で TTS controls 表示、ハイライト描画、auto page turn、MP3 export ボタン、edit ボタンの可視性を assert
- 現行 900 LOC 実装に対して green、解体後も green を維持

### Phase B — 3 widget への分解 (F005)
監査推奨に従い、以下に分割:

- **`TtsControlsBar`** (`lib/features/text_viewer/presentation/widgets/tts_controls_bar.dart`)
  - streaming/stored playback controller のライフタイム所有
  - `TtsAudioState × TtsPlaybackState` に応じた play/pause/stop/edit/export ボタン表示
  - F028 の `_withTtsControls` 4 引数 helper を吸収
- **`TextContentRenderer`** (`lib/features/text_viewer/presentation/widgets/text_content_renderer.dart`)
  - horizontal/vertical mode dispatch
  - スクロール/行追跡、ruby レンダリング、検索ハイライト、TTS ハイライト
  - F051 の `_segmentsCache` を Riverpod 経由で取得
- **`TextViewerPanel`** (既存ファイル、≤ 200 LOC のシェル)
  - レイアウト組み立てのみ
  - F029: `ref.listen(selectedFileProvider)` で file 変化を `initState` から駆動 (build 内 state 変更を排除)

### Phase C — 細かい改善
- **F046**: `TtsStreamingController` のコンストラクタを `ProviderContainer` 受け取りから `Reader = T Function<T>(ProviderListenable<T>)` 受け取りに変更。call site (`TtsControlsBar`) は `ref.read` を渡す
- **F051**: `lib/features/text_viewer/data/parsed_segments_cache_provider.dart` で `Provider<ParsedSegmentsCache>` を実装。キーはコンテンツの SHA-256 ハッシュ (`TtsEpisode.textHash` と同じ計算ロジックを共有)
- **F028**: `_withTtsControls` ヘルパは `TtsControlsBar` 抽出により消滅
- **F029**: `build` 内の `_lastViewedFilePath = selectedFile?.path` + `addPostFrameCallback` を `initState` の `ref.listen(selectedFileProvider, ...)` に置換

## Capabilities

### New Capabilities
- `text-viewer-composition`: テキストビューアパネルが 3 widget (`TtsControlsBar`, `TextContentRenderer`, `TextViewerPanel`) で構成されることを契約として固定。Sprint 4 の `settings-dialog-composition` と同パターン

### Modified Capabilities
- `tts-streaming-pipeline`: `TtsStreamingController` のコンストラクタが `ProviderContainer` ではなく `Reader` 関数型を受け取る (F046)

`text-viewer` 既存スペックの user-visible シナリオ (TTS controls 表示、ハイライト等) は実装ロケーションが widget を移動するだけで挙動は同じため、要件レベル変更は不要。

## Impact

- **Code (additions)**:
  - `lib/features/text_viewer/presentation/widgets/tts_controls_bar.dart`
  - `lib/features/text_viewer/presentation/widgets/text_content_renderer.dart`
  - `lib/features/text_viewer/data/parsed_segments_cache_provider.dart`
  - `lib/features/text_viewer/data/parsed_segments_cache.dart` (既存実装の Riverpod 化)
- **Code (modifications)**:
  - `lib/features/text_viewer/presentation/text_viewer_panel.dart` — 900 LOC → ≤200 LOC のシェル
  - `lib/features/tts/data/tts_streaming_controller.dart` — コンストラクタ API を `Reader` 受け取りに変更 (F046)
- **Tests (additions)**:
  - `test/features/text_viewer/presentation/text_viewer_panel_test.dart` (Phase A 統合テスト)
  - `test/features/text_viewer/presentation/widgets/tts_controls_bar_test.dart` (state × engine の組み合わせを網羅)
  - `test/features/text_viewer/presentation/widgets/text_content_renderer_test.dart`
  - `test/features/text_viewer/data/parsed_segments_cache_provider_test.dart`
  - `tts_streaming_controller` のテスト fixture を `Reader` 注入形式に更新 (F046 verification)
- **Dependencies**: 追加なし
- **BREAKING (内部 API)**: `TtsStreamingController` のコンストラクタシグネチャ変更 (F046)。lib 内の唯一の構築サイト (`TtsControlsBar`) も本 change で更新するため外部影響なし
- **UX**: 完全に不変
- **Risk**: 7 つの concerns を 3 widget に分配する際、状態購読の重複/欠落が発生しうる。Phase A の整合性テストで担保する
- **Pre-requisites**: Sprint 2 (DTO + Riverpod family) と Sprint 3 (`SegmentPlayer`) の landed が前提
