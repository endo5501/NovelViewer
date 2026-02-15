## 1. 通常文字の固定幅コンテナ対応

- [x] 1.1 `vertical_text_page.dart` の `_buildCharWidget` で通常文字を `SizedBox(width: fontSize)` + `Center` で囲むよう修正
- [x] 1.2 通常文字の固定幅中央揃えに関するテストを作成

## 2. ルビテキストの固定幅コンテナ対応

- [x] 2.1 `vertical_ruby_text_widget.dart` の `_buildVerticalText` でベース文字・ルビ文字それぞれを `SizedBox(width: fontSize)` + `Center` で囲むよう修正
- [x] 2.2 ルビテキストの固定幅中央揃えに関するテストを作成

## 3. 最終確認

- [x] 3.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [x] 3.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 3.3 `fvm flutter analyze`でリントを実行
- [x] 3.4 `fvm flutter test`でテストを実行
