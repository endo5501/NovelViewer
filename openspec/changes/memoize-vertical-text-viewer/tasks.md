## 1. F117: マーク計算の統合（computeMarkedEntries 削除）

- [x] 1.1 `vertical_marked_ranges_test.dart` に「`computeMarkedRanges` の結果が各エントリの `style` を保持する」テストを追加（旧 `computeMarkedEntries` の同値ケースを移植: solid/dotted、ルビ base のみ照合、1文字語スキップ、視覚的カラム折返しで分断されない、実改行で分断される、legacy 改行扱い）。実行して失敗を確認
- [x] 1.2 `MarkInfo`（`vertical_marked_ranges.dart`）に `final MarkStyle style;` を追加し、`==`/`hashCode` に含める。コンストラクタを更新
- [x] 1.3 `computeMarkedRanges` で `MarkSpan.style` を `MarkInfo.style` に載せる。1.1 のテストを通す
- [x] 1.4 `vertical_text_page.dart` の `computeMarkedEntries` 呼び出し（:169-173）を削除し、`markStyle:`（:200）を `_markedRanges[i]?.style` から導出するよう変更
- [x] 1.5 `vertical_marked_entries.dart` と `vertical_marked_entries_test.dart` を削除。`findMarks`/バッファ走査が build あたり1回になったことをテストで担保（カウンタ付きフックまたは観測フラグ）
- [x] 1.6 `fvm flutter analyze` と関連テスト（`vertical_marked_ranges_test.dart`, `vertical_text_page_*`, `tts_highlight_vertical_test.dart`）を実行して回帰がないことを確認
- [x] 1.7 F117 をコミット

## 2. F115: ページネーションのメモ化（重い層／軽い層の分離）

- [x] 2.1 `vertical_text_viewer` のテストに「同一 `(segments, constraints, style, columnSpacing)` での再ビルドで再ページネーションが走らない」回数スパイテストを追加。実行して失敗を確認
- [x] 2.2 「`constraints` 変化／`style` 変化でページが再計算される」「`bookmarkLineNumbers` のみ変化・`targetLine` のみ変化では重い層が再計算されないが、bookmarkPages/targetPage は更新される」同値性テストを追加。実行して失敗を確認
- [x] 2.3 `_paginateLines` を「重い層」（pages/pageStarts/lineBreakIndicesPerPage/charOffsetPerPage/lineStartColumns）と「軽い層」（targetPage/bookmarkPages/firstLinePerPage）に分割するヘルパへリファクタ（挙動を変えずに分離のみ）。既存テスト緑を確認
- [x] 2.4 重い層のキャッシュフィールド（`_cachedHeavy` と key: `_cachedSegments`/`_cachedConstraints`/`_cachedPaginateStyle`/`_cachedColumnSpacing`）を State に追加。`segments` は identity、他は値比較でキー一致時に再利用
- [x] 2.5 軽い層は毎ビルド、キャッシュ済み重い層から再計算して `_PaginationResult` を組む（キャッシュヒット時も `_PaginationResult` は毎ビルド生成し、build 内フィールド代入経路 `_pageCount`/`_currentPageSegments` を不変に保つ）。2.1/2.2 のテストを通す
- [x] 2.6 `didUpdateWidget`/`initState` での `_lines`・`_charEntries`・columns 再構築タイミングを確認し、それらに連動して重い層キャッシュが無効化されることを保証（`_cachedPainter`/`_cachedStyle` の既存無効化との整合も確認）
- [x] 2.7 キー/ホイール/スワイプ/初期ページ/フォント変更/アニメーション系テスト（`vertical_text_viewer_*_test.dart` 群）を実行して回帰がないことを確認
- [ ] 2.8 F115 をコミット

## 3. F116: ページ側マップ／ハイライトのメモ化と hit-region 条件化

- [x] 3.1 `_computeTtsHighlights` の依存（`ttsHighlightRange` 単体で十分か `_charEntries` identity も要るか）を精査し、メモ化キーを確定（design.md Open Questions）
- [x] 3.2 「選択ドラッグの `setState` でマーク再計算・TTSハイライト再計算が走らない」回数スパイテストを追加。実行して失敗を確認
- [x] 3.3 「TTSハイライトのみ変化では hit-region 再構築がスケジュールされない」「entries/style/layout 変化では hit-region 再構築がスケジュールされる」テストを追加。実行して失敗を確認
- [x] 3.4 `_markedRanges` を `(entries identity, markedWords identity, lineBreakEntryIndices)` キーでメモ化
- [x] 3.5 `_computeTtsHighlights` 結果を 3.1 で確定したキーでメモ化
- [x] 3.6 `_scheduleHitRegionRebuild()`（:209 無条件呼び出し）を、前回ビルドからの entries/style/layout 変化時のみ呼ぶよう条件化。3.2/3.3 のテストを通す
- [x] 3.7 「レンダリング出力（表示・検索/TTSハイライト・選択・マーク下線・ヒットテスト）が非メモ化版と同一」同値性テストを追加して通す
- [x] 3.8 ホバー系（`vertical_text_page_hover_test.dart`）・選択系・ヒットテスト系テストで回帰がないことを確認（特に `MarkInfo` 等価性変更後のホバー合体ロジック）
- [ ] 3.9 F116 をコミット

## 4. 最終確認

- [x] 4.1 code-reviewスキルを使用してコードレビューを実施
- [x] 4.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 4.3 `fvm flutter analyze`でリントを実行
- [x] 4.4 `fvm flutter test`でテストを実行
