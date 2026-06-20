## 1. テスト作成（RED）

- [x] 1.1 `test/features/tts/data/text_segmenter_test.dart` に英語文末分割のテストを追加（`.` `!` `?` + 空白で分割、小数点 `3.14` は非分割）
- [x] 1.2 同テストに長文の半角読点 `,` 分割テストを追加（読点を第1セグメント末尾に含む）
- [x] 1.3 同テストに読点なし長文の空白（単語境界）分割テストを追加（単語の途中で切れないこと）
- [x] 1.4 報告された英語段落の回帰テストを追加（先頭文が単独セグメント、各非末尾セグメントが `.` `,` `!` `?` で終わること）
- [x] 1.5 `fvm flutter test test/features/tts/data/text_segmenter_test.dart` を実行し、新規テストが期待通り失敗することを確認

## 2. 実装（GREEN）

- [x] 2.1 `_sentenceEnders` に半角 `.` `!` `?` を扱う判定を追加し、「直後が空白・文末・閉じ括弧のときのみ文末」とするヘルパーを `_splitTextBySentence` に組み込む
- [x] 2.2 `_closingBrackets` に半角 `"` `)` を追加（`'` は追加しない）
- [x] 2.3 `_findSplitPosition` を「半角/全角読点 → 空白（単語境界）→ 200文字強制」の優先順位に変更
- [x] 2.4 `fvm flutter test test/features/tts/data/text_segmenter_test.dart` を実行し、新規・既存テストが全て通過することを確認

## 3. リファクタリング・回帰確認

- [x] 3.1 既存の日本語分割・オフセット・ルビ・長文分割テストが不変で通過することを確認（後方互換）
- [x] 3.2 重複ロジックの整理と命名見直し（テストはGREENのまま維持）

## 4. 最終確認

- [x] 4.1 code-reviewスキルを使用してコードレビューを実施
- [x] 4.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 4.3 `fvm flutter analyze`でリントを実行
- [x] 4.4 `fvm flutter test`でテストを実行
