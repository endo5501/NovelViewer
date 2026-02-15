## 1. テスト作成（TDD: Red）

- [x] 1.1 `vertical_text_page.dart` の空カラムレンダリングに関するテストを作成: 改行エントリの `SizedBox` が `width: 0` ではなく `width: charWidth`（フォントサイズ相当）を持つことを検証
- [x] 1.2 `vertical_text_viewer.dart` のページネーションに関するテストを作成: 空カラムが通常カラムと同じ幅でページ幅計算に含まれることを検証
- [x] 1.3 テストを実行し、失敗を確認（Red状態）

## 2. 実装（TDD: Green）

- [x] 2.1 `vertical_text_page.dart` の空カラム識別ロジックを追加: `_computeEmptyColumnNewlines` で空カラムのニューラインを特定し、buildループで選択的に幅を付与
- [x] 2.2 `vertical_text_viewer.dart` の `_groupColumnsIntoPages` を修正: 空カラムのセンチネルに `charWidth` を加算（追加のキャラクターランは不要）
- [x] 2.3 テストを実行し、全テスト通過を確認（Green状態）

## 3. 既存テストの更新

- [x] 3.1 `vertical_text_pagination_font_test.dart` の空行関連テストの期待値を更新（既存テストは修正不要で全通過）
- [x] 3.2 全テストを実行し確認（498通過、4失敗は既存問題で本変更と無関係）

## 4. 最終確認

- [x] 4.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [x] 4.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 4.3 `fvm flutter analyze`でリントを実行
- [x] 4.4 `fvm flutter test`でテストを実行
