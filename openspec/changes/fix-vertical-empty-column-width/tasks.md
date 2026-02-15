## 1. テスト作成（TDD: Red）

- [ ] 1.1 `vertical_text_page.dart` の空カラムレンダリングに関するテストを作成: 改行エントリの `SizedBox` が `width: 0` ではなく `width: charWidth`（フォントサイズ相当）を持つことを検証
- [ ] 1.2 `vertical_text_viewer.dart` のページネーションに関するテストを作成: 空カラムが通常カラムと同じ幅でページ幅計算に含まれることを検証
- [ ] 1.3 テストを実行し、失敗を確認（Red状態）

## 2. 実装（TDD: Green）

- [ ] 2.1 `vertical_text_page.dart` の `_buildCharWidget` を修正: `isNewline` の場合に `SizedBox(width: 0, height: double.infinity)` → `SizedBox(width: charWidth, height: double.infinity)` に変更
- [ ] 2.2 `vertical_text_viewer.dart` の `_groupColumnsIntoPages` を修正: 空カラムにも `charWidth` を加算するよう `hasText` 分岐を削除または修正
- [ ] 2.3 テストを実行し、全テスト通過を確認（Green状態）

## 3. 既存テストの更新

- [ ] 3.1 `vertical_text_pagination_font_test.dart` の空行関連テストの期待値を更新（ゼロ幅前提のアサーションを修正）
- [ ] 3.2 全テストを実行し、既存テストが全て通過することを確認

## 4. 最終確認

- [ ] 4.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [ ] 4.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 4.3 `fvm flutter analyze`でリントを実行
- [ ] 4.4 `fvm flutter test`でテストを実行
