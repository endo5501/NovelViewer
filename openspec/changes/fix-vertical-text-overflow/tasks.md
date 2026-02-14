## 1. ページネーション計算の修正

- [x] 1.1 `vertical_text_viewer.dart`の`_paginateLines`メソッドで、`maxColumnsPerPage`の計算式を修正する。現在の`(availableWidth / (charWidth + runSpacing)).floor()`を`((availableWidth + 2 * runSpacing) / (charWidth + 2 * runSpacing)).floor()`に変更し、Wrapのsentinelによるrunspacing二重適用を正しく考慮する
- [x] 1.2 修正後の計算式が正しいことを検証するユニットテストを追加する（フォントサイズ17.0を含む複数のフォントサイズで、計算上の総幅がavailableWidthを超えないことを確認）

## 2. クリッピングの追加

- [x] 2.1 `vertical_text_page.dart`の`build`メソッドで、`Directionality` + `Wrap`を`ClipRect`で囲み、表示領域を超えたコンテンツが視覚的にはみ出さないようにする
- [x] 2.2 ClipRect追加後にテキスト選択・ヒットテストが正常に動作することを既存テストで確認する

## 3. 回帰テスト

- [x] 3.1 フォントサイズ10.0〜32.0の範囲でページネーション計算が正しく動作し、テキストがはみ出さないことを確認するテストを追加または既存テストを更新する
- [x] 3.2 既存の`vertical_text_viewer_test.dart`および`vertical_text_pagination_font_test.dart`が全てパスすることを確認する

## 4. 最終確認

- [x] 4.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [x] 4.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 4.3 `fvm flutter analyze`でリントを実行
- [x] 4.4 `fvm flutter test`でテストを実行
