## 1. テスト作成（TDD: Red）

- [x] 1.1 `test/features/text_viewer/data/vertical_marked_ranges_test.dart` に、視覚的改行（`lineBreakEntryIndices` 非該当）をまたぐ単語がマッチし両側エントリへ同一 `MarkInfo` が割り当てられるテストを追加
- [x] 1.2 同テストに、本物の改行（`lineBreakEntryIndices` 該当）をまたぐ単語はマッチしないテストを追加
- [x] 1.3 `test/features/text_viewer/data/vertical_marked_entries_test.dart` に、視覚的改行をまたぐ単語へ傍線スタイルが両側エントリに付与されるテストを追加
- [x] 1.4 `test/features/text_viewer/data/vertical_text_layout_test.dart` に、視覚的改行をまたぐ選択は改行なしの連続文字列を返し、本物の改行をまたぐ選択は `\n` を含むテストを追加
- [x] 1.5 引数省略時（既存呼び出し互換）に全改行を境界として扱う後方互換テストを各関数へ追加
- [x] 1.6 `fvm flutter test` を実行し、追加テストが失敗（Red）することを確認

## 2. 実装（TDD: Green）

- [x] 2.1 `computeMarkedRanges`（`vertical_marked_ranges.dart`）に任意引数 `Set<int>? lineBreakEntryIndices`（null=従来どおり全改行を境界扱い）を追加し、buffer 構築時に視覚的改行エントリ（集合非該当の改行）を `\n` 書き込み・`positionToEntry` 追加の対象から除外
- [x] 2.2 `computeMarkedEntries`（`vertical_marked_entries.dart`）に同様の引数と除外ロジックを追加
- [x] 2.3 `extractVerticalSelectedText`（`vertical_text_layout.dart`）に同様の引数を追加し、視覚的改行エントリは `\n` を出力せずスキップ
- [x] 2.4 `vertical_text_page.dart` の `build()` 内で `computeMarkedRanges` / `computeMarkedEntries` 呼び出しへ `widget.lineBreakEntryIndices` を引き渡し（widgetフィールドも nullable 化しアウトゴーイングページ/既存テストの従来動作を維持）
- [x] 2.5 `vertical_text_page.dart` の `_onSecondaryTapUp` / `_notifySelectionChanged` の `extractVerticalSelectedText` 呼び出しへ `widget.lineBreakEntryIndices` を引き渡し
- [x] 2.6 `fvm flutter test` を実行し、追加テストが成功（Green）することを確認

## 3. 動作確認

- [ ] 3.1 縦書き表示で、桁の折り返し位置にまたがる解析済み単語に傍線・ポップアップが表示されることを確認
- [ ] 3.2 折り返しにまたがる単語を選択して再解析し、改行を含まない正しい単語として解析されることを確認
- [ ] 3.3 本物の段落改行をまたぐ単語が誤マッチしないこと、横書き表示が従来どおり動作することを確認

## 4. 最終確認

- [x] 4.1 code-reviewスキルを使用してコードレビューを実施（重大な指摘なし）
- [x] 4.2 codexスキルを使用して現在開発中のコードレビューを実施（#1/#2は実害なしと検証、#3はrubyガードテストを追加）
- [x] 4.3 `fvm flutter analyze`でリントを実行（No issues found）
- [x] 4.4 `fvm flutter test`でテストを実行（全テストパス）
