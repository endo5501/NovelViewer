## 1. データモデル

- [x] 1.1 `TextSegment` sealed class、`PlainTextSegment`、`RubyTextSegment` を作成する (`lib/features/text_viewer/data/text_segment.dart`)
- [x] 1.2 `TextSegment` のユニットテストを作成する（等価性の確認など）

## 2. ルビテキストパーサー

- [x] 2.1 `parseRubyText(String content)` 関数のテストを作成する（標準ルビタグ、rpなしルビタグ、複数ルビ、ルビなしテキスト、複数行混合コンテンツ）
- [x] 2.2 正規表現ベースの `parseRubyText()` 関数を実装する (`lib/features/text_viewer/data/ruby_text_parser.dart`)
- [x] 2.3 `buildPlainText(List<TextSegment> segments)` 関数のテストを作成する
- [x] 2.4 `buildPlainText()` 関数を実装する

## 3. ルビテキスト描画

- [x] 3.1 `RubyTextWidget` を作成する（WidgetSpan内で使用する、ルビを上に・ベーステキストを下に表示するColumn）
- [x] 3.2 `buildRubyTextSpans(List<TextSegment> segments, TextStyle? baseStyle, String? query)` 関数のテストを作成する
- [x] 3.3 `buildRubyTextSpans()` 関数を実装する（PlainTextSegmentはTextSpan、RubyTextSegmentはWidgetSpanで描画）

## 4. 検索ハイライト統合

- [x] 4.1 ルビ付きテキストでの検索ハイライトのテストを作成する（プレーンテキスト内マッチ、ルビベーステキスト内マッチ）
- [x] 4.2 `buildRubyTextSpans()` にハイライト処理を統合する

## 5. TextViewerPanel統合

- [x] 5.1 `TextViewerPanel` を変更し、新しいパイプライン（parseRubyText → buildPlainText → buildRubyTextSpans）を使用する
- [x] 5.2 テキスト選択の `onSelectionChanged` コールバックをプレーンテキストベースに更新する
- [x] 5.3 既存の `buildHighlightedTextSpan` 関数を `buildRubyTextSpans` に置き換える

## 6. 最終確認

- [x] 6.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [x] 6.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 6.3 `fvm flutter analyze`でリントを実行
- [x] 6.4 `fvm flutter test`でテストを実行
