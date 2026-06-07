## 1. データ層: 回転対象の定義（TDD）

- [x] 1.1 `vertical_char_map.dart` の回転判定ヘルパ（例: `shouldRotateVertical(String char) -> bool`）に対するテストを先に作成し、対象文字（`"` `＂` `"` `"` / `'` `＇` `'` `'` / `` ` `` `｀` / `:` `：` / `;` `；`）で `true`、その他で `false` を返すことを期待するテストを書く（失敗を確認）
- [x] 1.2 `verticalCharMap` から `:` `：` `;` `；` のエントリが削除され、`mapToVerticalChar` がこれらを置換せず原文字を返すことを確認するテストを追加（失敗を確認）
- [x] 1.3 テストをパスさせる実装: 回転対象集合 `verticalRotateChars` と `shouldRotateVertical` を追加し、`verticalCharMap` からコロン・セミコロンのエントリを削除

## 2. 表示層: 物理回転の適用（TDD）

- [x] 2.1 `vertical_text_page.dart` の `_buildCharWidget` で、回転対象文字が `RotatedBox(quarterTurns: 1)` で包まれ、かつ原文字（非置換）が描画されることを検証するウィジェットテストを作成（失敗を確認）
- [x] 2.2 非回転文字は従来どおり `mapToVerticalChar` を通した `Text` が描画されることを検証するテストを追加（回帰防止）
- [x] 2.3 テストをパスさせる実装: `_buildCharWidget` に回転分岐を追加（固定幅 `SizedBox` 内に `RotatedBox` を配置）

## 3. ルビ経路の整合（TDD）

- [x] 3.1 `vertical_ruby_text_widget.dart` で、ベース文字/ルビ文字に回転対象約物が含まれる場合に同じ90°回転が適用されることを検証するテストを作成（失敗を確認）
- [x] 3.2 テストをパスさせる実装: 回転判定・回転描画を共通ヘルパ経由に揃え、ルビ経路へ適用

## 4. 回帰確認（選択・ハイライト）

- [x] 4.1 回転対象文字を含むテキストで、文字数・テキストオフセットが不変であり、検索ハイライト/TTSハイライトのオフセット整合が維持されることをテストで確認
- [x] 4.2 ヒットテスト（セル矩形/選択範囲）が回転文字を含む行でも正しく機能することを確認

## 5. 実機目視確認

- [x] 5.1 `fvm flutter run`（または既存ビルド）で `"` `'` `` ` `` `:` `;`（全角/半角/カーリー含む）を縦書き表示し、回転方向（時計回り90°）が自然に見えることをWindowsで目視確認（tmp/置換確認結果.png で良好を確認）
- [x] 5.2 クオート方向が不自然な場合は `quarterTurns` を再検討し、決定を design.md に追記（時計回り90°=Transform.rotate(π/2)で自然と確認済み、調整不要）

## 6. 最終確認

- [x] 6.1 code-reviewスキルを使用してコードレビューを実施（RotatedBoxによるセル高縮みリスクを検出）
- [x] 6.2 codexスキルを使用して現在開発中のコードレビューを実施（同上をHigh指摘→Transform.rotateへ修正）
- [x] 6.3 `fvm flutter analyze`でリントを実行（No issues found）
- [x] 6.4 `fvm flutter test`でテストを実行（全1869テスト通過）
