## Why

縦書きビューアは、TTSハイライトの1ティック・選択ドラッグの1ポインタ移動・ページ送りの`setState`ごとに、小説全体の再ページネーション（flatten＋禁則処理＋段組＋オフセット計算）とマークマップ・ハイライトの全文走査を毎ビルド行っている。横書き側は同じ問題を identity キーのメモ化で既に解決済みで、縦書きだけが非対称に重い（TECH_DEBT_AUDIT.md F115/F116/F117）。100K文字級の小説でTTS再生中に毎ティック全文計算が走るため、体感の引っかかりと無駄なCPU消費の原因になっている。

## What Changes

- **F117**: `computeMarkedEntries` と `computeMarkedRanges` が同一のバッファ走査＋`findMarks`を重複実装し両方が毎ビルド呼ばれている問題を解消する。`MarkInfo` に `style` フィールドを畳み込み、char-entry→`MarkStyle` のマップを `computeMarkedRanges` の結果から導出する。`computeMarkedEntries` を**削除**する（findMarks 呼び出しが 2回→1回/build）。
- **F115**: `VerticalTextViewer._paginateLines` の結果のうち「重い層」（pages / pageStarts / lineBreakIndicesPerPage / charOffsetPerPage / lineStartColumns）を `(segments identity, constraints, style, columnSpacing)` キーでメモ化する。`targetPage` / `bookmarkPages` / `firstLinePerPage` の「軽い層」はキャッシュ外で毎ビルド再計算し、ブックマーク追加やターゲット行ジャンプで重いキャッシュを無効化しない。
- **F116**: `VerticalTextPage.build` のマークマップ・TTSハイライト集合を入力（entries identity / markedWords / lineBreakEntryIndices / ttsRange）でメモ化する。無条件の `_scheduleHitRegionRebuild()` を、ヒット領域に影響する入力（entries / style / layout）が変化したときのみ実行するよう条件化する。
- 上記いずれも**レンダリング出力（表示・ハイライト・選択・ヒットテスト）は不変**。観測可能な振る舞いの変更はない（性能特性のみ）。

## Capabilities

### New Capabilities
<!-- なし。新しいユーザー向け能力は導入しない。 -->

### Modified Capabilities
- `vertical-text-display`: 縦書きレンダリングのメモ化に関する非機能要件を追加する。入力が不変の再ビルド（TTSティック・選択ドラッグ・ページ送り）では全文の再ページネーション／マーク再計算を行わず、かつレンダリング出力は入力変化時に正しく更新されること、を SHALL 要件として定義する。

## Impact

- `lib/features/text_viewer/data/vertical_marked_ranges.dart`（`MarkInfo` に `style` 追加）
- `lib/features/text_viewer/data/vertical_marked_entries.dart`（**削除**）
- `lib/features/text_viewer/presentation/vertical_text_page.dart`（マップ統合・メモ化・hit-region 条件化）
- `lib/features/text_viewer/presentation/vertical_text_viewer.dart`（`_paginateLines` メモ化、重い/軽い層の分離）
- 既存テスト資産: `test/.../vertical_marked_entries_test.dart`（削除関数のテストは `vertical_marked_ranges_test.dart` へ統合）、`vertical_marked_ranges_test.dart`、縦書きビューア／ページ系テスト群
- 横書き側 `widgets/text_content_renderer.dart:630-658`（`_cachedTextSpan`）と `:496-534`（`_cachedBookmarkLineYs`）が実装の手本
- 破壊的変更なし。外部API・依存・DBスキーマへの影響なし
