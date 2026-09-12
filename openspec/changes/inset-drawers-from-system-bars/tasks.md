## 1. テスト（先に書いて失敗を確認する）

- [x] 1.1 `test/home_screen_adaptive_shell_test.dart` に、`tester.view.padding` へ `FakeViewPadding` を設定してインセットのある画面を再現するヘルパを足す。ティアダウンで `tester.view.reset()` を呼ぶ
- [x] 1.2 narrow レイアウトで左ドロワーを開き、タブバーの上端が上インセットの内側にあることを検証するテストを書く
- [x] 1.3 narrow レイアウトで左ドロワーを開き、中身の下端が下インセットの手前で終わることを検証するテストを書く
- [x] 1.4 narrow レイアウトで右ドロワーを開き、検索パネルの中身が上下のインセットの内側にあることを検証するテストを書く
- [x] 1.5 ドロワーの面そのものは画面上端まで届いていることを検証するテストを書く
- [x] 1.6 wide レイアウトではインセットのある画面でも左カラムと右カラムの配置が変わらないことを検証するテストを書く
- [x] 1.7 `fvm flutter test test/home_screen_adaptive_shell_test.dart` を実行し、新しいテストが期待どおり失敗することを確認する
- [ ] 1.8 失敗するテストをコミットする

## 2. 実装

- [ ] 2.1 `lib/home_screen.dart` の `drawer` で `LeftColumnPanel` を `SafeArea` で包む
- [ ] 2.2 `lib/home_screen.dart` の `endDrawer` で `SearchResultsPanel` を `SafeArea` で包む
- [ ] 2.3 なぜドロワーだけに必要でパネル側に置かないのかを、既存のコメントの書き方に合わせて残す
- [ ] 2.4 `fvm flutter test test/home_screen_adaptive_shell_test.dart` を実行し、新しいテストが通ることを確認する
- [ ] 2.5 既存のドロワー関連テストが引き続き通ることを確認する

## 3. 最終確認

- [ ] 3.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 3.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 3.3 `fvm dart format .`でフォーマットを実行
- [x] 3.4 `fvm flutter analyze`でリントを実行
- [x] 3.5 `fvm flutter test`でテストを実行
