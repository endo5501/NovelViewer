## Why

テキスト検索のハイライトに `Colors.yellow` がハードコードされており、ダークモードではテキスト色（白）との コントラストが不足して文字が読めなくなる。ダークモードでも検索結果が視認できるようにハイライト色をテーマに応じて切り替える必要がある。

## What Changes

- 検索ハイライトの背景色をテーマ対応にする（ライトモード: 現行の黄色、ダークモード: 視認性の高い色）
- ダークモード時はハイライト部分のテキスト色も明示的に設定し、コントラストを確保する
- 対象は3箇所:
  - `vertical_text_page.dart` の `_createTextStyle()`
  - `vertical_ruby_text_widget.dart` の `_buildBaseText()`
  - `ruby_text_builder.dart` の `_buildHighlightedPlainSpans()`

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `text-search`: 検索ハイライトの表示がダークモードで視認可能になるよう、テーマに応じたハイライト色を使用する

## Impact

- **変更ファイル**: `vertical_text_page.dart`, `vertical_ruby_text_widget.dart`, `ruby_text_builder.dart`
- **テスト**: 既存のハイライト色テスト（`Colors.yellow` を検証しているテスト）の期待値をテーマ対応に更新
- **既存機能への影響**: ライトモードでは現行と同じ見た目を維持。ダークモードでのみ表示が改善される
