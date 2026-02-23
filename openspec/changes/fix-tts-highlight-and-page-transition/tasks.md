## 1. TextSegmenter のオフセット計算修正

- [ ] 1.1 `TextSegmenter._rubyTagPattern` を `ruby_text_parser.dart` の `_rubyPattern` と同じパターンに更新する（`<rb>` タグ対応を含む）。可能であれば共通定数として `text_segment.dart` または共有モジュールに定義する
- [ ] 1.2 `TextSegmenter.splitIntoSentences` の改行分割時の `.trim()` 処理で、`offset` を先頭空白分だけ進め、`length` を trimLeft + trimRight 後の文字数に修正する
- [ ] 1.3 TextSegmenter の既存テストを更新し、Ruby タグパターン統一のテスト（`<rb>` タグ付き入力）と trim オフセット補正のテスト（先頭全角スペース付き行）を追加する

## 2. TextViewerPanel のセグメントメモ化

- [ ] 2.1 `_TextViewerPanelState` に `_lastContent` (String?) と `_cachedSegments` (List<TextSegment>?) フィールドを追加し、content が変更された場合のみ `parseRubyText` を再実行するメソッドを実装する
- [ ] 2.2 `build()` 内の `parseRubyText(content)` 呼び出しをメモ化メソッドに置き換える
- [ ] 2.3 セグメントメモ化のテストを追加する：同じ content で2回呼び出した場合に同一参照が返ることを検証

## 3. VerticalTextViewer のページオフセット計算修正

- [ ] 3.1 `_paginateLines` 内で各ページのグローバルテキストオフセットを、元のテキスト行構造から計算するロジックを実装する。合成改行（カラム折り返しによる `PlainTextSegment('\n')`）をカウントに含めない
- [ ] 3.2 `_computeCharOffsetPerPage` を新しいオフセット計算に置き換える、または `_paginateLines` から直接正確なオフセットリストを返す
- [ ] 3.3 `_PaginationResult` に `charOffsetPerPage` の新しい値（合成改行を除外したオフセット）が含まれることを確認する
- [ ] 3.4 `VerticalTextViewer.didUpdateWidget` の `oldWidget.segments != widget.segments` が true の場合のみ `_currentPage = 0` にリセットする動作が、セグメントメモ化（タスク2）と組み合わせて正しく動作することを検証するテストを追加する
- [ ] 3.5 ページオフセット計算のユニットテストを追加する：折り返しなし、折り返しあり、Ruby テキスト混在の各ケースで正確なオフセットが算出されることを検証

## 4. VerticalTextPage の TTS ハイライト修正

- [ ] 4.1 `VerticalTextPage` に `pageStartTextOffset` (int, デフォルト0) プロパティを追加する
- [ ] 4.2 `VerticalTextViewer` から `VerticalTextPage` への `pageStartTextOffset` の受け渡しを実装する（`_paginateLines` の結果から取得）
- [ ] 4.3 `_computeTtsHighlights()` を修正する：グローバル TTS 範囲を `pageStartTextOffset` で page-local 範囲に変換し、`plainTextOffset` のカウントで newline エントリをスキップする
- [ ] 4.4 TTS ハイライト計算のユニットテストを追加する：ページ1（折り返しなし）、ページ1（折り返しあり）、ページ2以降、範囲外のケースを検証

## 5. 最終確認

- [ ] 5.1 code-simplifier エージェントを使用してコードをよりシンプルにできないか確認
- [ ] 5.2 codex スキルを使用して現在開発中のコードレビューを実施
- [ ] 5.3 `fvm flutter analyze` でリントを実行
- [ ] 5.4 `fvm flutter test` でテストを実行
