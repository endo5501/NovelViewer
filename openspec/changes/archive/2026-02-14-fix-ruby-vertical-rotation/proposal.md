## Why

縦書き表示モードにおいて、ルビ（ふりがな）の文字に縦書き用の文字マッピング（`verticalCharMap`）が適用されていない。通常テキストやルビの親文字（base text）には `mapToVerticalChar()` による文字変換が行われているが、ルビテキスト自体には適用されていないため、括弧やダッシュなどの記号がルビに含まれる場合に正しい縦書き表示にならない。

## What Changes

- ルビテキストの文字列に対して `mapToVerticalChar()` による縦書き文字マッピングを適用する
- `VerticalRubyTextWidget` でルビ文字を構築する際に、親文字と同様の文字変換処理を追加する

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `ruby-text-rendering`: ルビテキストの縦書き表示時に、ルビ文字にも `verticalCharMap` による文字マッピングを適用する要件を追加

## Impact

- `lib/features/text_viewer/presentation/vertical_ruby_text_widget.dart`: ルビ文字の変換ロジックを修正
- 既存のルビテキストレンダリングのテストに縦書きマッピングの検証を追加
