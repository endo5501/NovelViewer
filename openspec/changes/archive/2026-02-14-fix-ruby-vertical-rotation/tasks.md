## 1. テスト作成

- [x] 1.1 `VerticalRubyTextWidget` のテストで、ルビ文字に `verticalCharMap` マッピング対象の文字（括弧、ダッシュ、句読点など）が含まれる場合に、縦書き用文字に変換されることを検証するテストを作成
- [x] 1.2 ルビ文字がひらがな・カタカナのみの場合に変換されないことを検証するテストを作成

## 2. 実装

- [x] 2.1 `vertical_ruby_text_widget.dart` の `build()` メソッドで、ルビ文字リスト構築時に `mapToVerticalChar()` を適用するよう修正

## 3. 最終確認

- [x] 3.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [x] 3.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 3.3 `fvm flutter analyze`でリントを実行
- [x] 3.4 `fvm flutter test`でテストを実行
