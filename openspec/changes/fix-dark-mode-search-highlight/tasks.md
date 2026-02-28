## 1. テスト更新（TDD: テストファースト）

- [ ] 1.1 `test/features/text_viewer/ruby_text_spans_test.dart` にダークモードでの検索ハイライト色テストを追加する（`Colors.amber.shade700` 背景、`Colors.black` テキスト色を期待）
- [ ] 1.2 `test/features/text_viewer/presentation/vertical_text_page_test.dart` にダークモードでの検索ハイライト色テストを追加する
- [ ] 1.3 `test/features/text_viewer/presentation/tts_highlight_horizontal_test.dart` のダークモードハイライト色テストを追加する
- [ ] 1.4 `test/features/text_viewer/presentation/tts_highlight_vertical_test.dart` のダークモードハイライト色テストを追加する
- [ ] 1.5 テストを実行し、期待通りに失敗することを確認する

## 2. ヘルパー関数の実装

- [ ] 2.1 `ruby_text_builder.dart` に `searchHighlightBackground(Brightness)` と `searchHighlightForeground(Brightness)` ヘルパー関数を追加する
- [ ] 2.2 `buildRubyTextSpans()` に `Brightness` パラメータを追加し、`_buildHighlightedPlainSpans()` に伝播させる
- [ ] 2.3 `_buildHighlightedPlainSpans()` でヘルパー関数を使用してテーマ対応のスタイルを適用する

## 3. Widget側の実装

- [ ] 3.1 `vertical_text_page.dart` の `_createTextStyle()` で `Theme.of(context).brightness` を使用してヘルパー関数からハイライト色を取得する
- [ ] 3.2 `vertical_ruby_text_widget.dart` の `_buildBaseText()` で `Theme.of(context).brightness` を使用してヘルパー関数からハイライト色を取得する
- [ ] 3.3 `buildRubyTextSpans()` の呼び出し元で `Brightness` パラメータを渡すように更新する
- [ ] 3.4 テストを実行し、全テストが通過することを確認する

## 4. 最終確認

- [ ] 4.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [ ] 4.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 4.3 `fvm flutter analyze`でリントを実行
- [ ] 4.4 `fvm flutter test`でテストを実行
