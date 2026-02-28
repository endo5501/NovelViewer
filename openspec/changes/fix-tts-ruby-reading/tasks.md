## 1. テスト更新（TDD: テストファースト）

- [ ] 1.1 `test/features/tts/data/text_segmenter_test.dart` のルビ関連テストの期待値をruby text（ふりがな）に変更する
  - `strips ruby tags and uses base text only`: `漢字を読む。` → `かんじを読む。`（テスト名も `strips ruby tags and uses ruby text for reading` に変更）
  - `strips multiple ruby tags`: `東京の空。` → `とうきょうのそら。`
  - `strips ruby tags with rb element`: `漢字を読む。` → `かんじを読む。`（offset/length も更新）
  - `strips ruby tags with rb and rp elements`: `漢字を読む。` → `かんじを読む。`（offset/length も更新）
  - `produces same plain text as parseRubyText for rb format`: `東京の空。` → `とうきょうのそら。`
- [ ] 1.2 テストを実行し、期待通りに失敗することを確認する（`fvm flutter test test/features/tts/data/text_segmenter_test.dart`）

## 2. 実装

- [ ] 2.1 `lib/features/tts/data/text_segmenter.dart` の `_rubyTagPattern` 正規表現に `<rt>` 内容のキャプチャグループを追加する（`<rt>.*?</rt>` → `<rt>(.*?)</rt>`）
- [ ] 2.2 `_stripRubyTags()` メソッドの戻り値を `match.group(1)` から `match.group(2)` に変更する
- [ ] 2.3 テストを実行し、全テストが通過することを確認する（`fvm flutter test test/features/tts/data/text_segmenter_test.dart`）

## 3. 最終確認

- [ ] 3.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [ ] 3.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 3.3 `fvm flutter analyze`でリントを実行
- [ ] 3.4 `fvm flutter test`でテストを実行
