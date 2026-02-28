## 1. テストの作成（TDD: Red）

- [ ] 1.1 `_cleanupFiles` が既に削除済みのファイルに対してエラーを投げないことを検証するテストを作成
- [ ] 1.2 `stop()` 完了時にファイル削除が完了済みであることを検証するテストを作成
- [ ] 1.3 テストを実行し、失敗を確認

## 2. 実装（TDD: Green）

- [ ] 2.1 `stop()` 内で `_cleanupFiles()` を Provider 状態更新の前に移動
- [ ] 2.2 `_cleanupFiles()` に `PathNotFoundException` を無視する try-catch を追加
- [ ] 2.3 テストを実行し、全テスト通過を確認

## 3. 最終確認

- [ ] 3.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [ ] 3.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 3.3 `fvm flutter analyze`でリントを実行
- [ ] 3.4 `fvm flutter test`でテストを実行
