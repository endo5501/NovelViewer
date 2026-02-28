## 1. テスト更新（TDD: テストファースト）

- [x] 1.1 `test/features/tts/data/text_segmenter_test.dart` のルビ関連テストの期待値をruby text（ふりがな）に変更する
- [x] 1.2 テストを実行し、期待通りに失敗することを確認する

## 2. 実装（初回 - 単純なgroup変更）

- [x] 2.1 `_rubyTagPattern` 正規表現に `<rt>` 内容のキャプチャグループを追加
- [x] 2.2 `_stripRubyTags()` の戻り値を `match.group(2)` に変更
- [x] 2.3 テストを実行し、全テストが通過することを確認

## 3. コードレビュー（座標系不整合の発見）

- [x] 3.1 code-simplifierエージェントで確認
- [x] 3.2 codexスキルでコードレビュー → offset/length座標系不整合を検出

## 4. 座標系修正テスト（TDD: テストファースト）

- [x] 4.1 テストを更新: `text` はruby text、`offset`/`length` はbase text座標系を期待するように変更
  - `strips ruby tags with rb element`: length を 7 → 6 に戻す（base text座標系）
  - `strips ruby tags with rb and rp elements`: length を 7 → 6 に戻す（base text座標系）
  - 新テスト追加: ruby textとbase textの長さが異なる場合にoffset/lengthがbase text座標系であることを検証
  - 新テスト追加: 空の `<rt>` タグでbase textにフォールバックすることを検証
- [x] 4.2 テストを実行し、期待通りに失敗することを確認する

## 5. 座標系修正の実装

- [x] 5.1 `_stripRubyTags()` を `useRubyText` パラメータ付きに変更する
- [x] 5.2 文分割ロジックを `_splitText()` プライベートメソッドに抽出する
- [x] 5.3 `splitIntoSentences()` で二重ストリッピング+zipを実装する
- [x] 5.4 テストを実行し、全テストが通過することを確認する

## 6. 最終確認

- [x] 6.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [x] 6.2 codexスキルを使用して最終コードレビューを実施
- [x] 6.3 `fvm flutter analyze`でリントを実行
- [x] 6.4 `fvm flutter test`でテストを実行
