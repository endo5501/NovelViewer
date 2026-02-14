## 1. 実装

- [ ] 1.1 `macos/Runner/MainFlutterWindow.swift` の `awakeFromNib()` メソッドで `super.awakeFromNib()` の後に `self.zoom(nil)` を追加する

## 2. 動作確認

- [ ] 2.1 `fvm flutter build macos` でビルドが成功することを確認
- [ ] 2.2 アプリを起動し、ウィンドウが画面いっぱい（メニューバー・Dock除外）に最大化されることを確認
- [ ] 2.3 最大化状態でメニューバーとDockが通常通り表示されていることを確認
- [ ] 2.4 タイトルバーの緑ボタンをクリックして元のサイズに戻せることを確認

## 3. 最終確認

- [ ] 3.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [ ] 3.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 3.3 `fvm flutter analyze`でリントを実行
- [ ] 3.4 `fvm flutter test`でテストを実行
