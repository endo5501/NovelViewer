## 1. テスト作成（TDD: Red）

- [x] 1.1 `test/features/text_download/download_dialog_test.dart` に、小説フォルダ内からダウンロードしても `libraryPathProvider` のパスが保存先として使用されることを検証するテストを追加する。テストでは `currentDirectoryProvider` をサブフォルダに設定し、`libraryPathProvider` をルートに設定した状態でダウンロードが正しくルートパスを使うことを確認する
- [x] 1.2 テストを実行し、失敗することを確認する（`currentDirectoryProvider` が使われているため失敗するはず）
- [x] 1.3 テストが正しく失敗することを確認できたらコミットする

## 2. 実装（TDD: Green）

- [x] 2.1 `lib/features/text_download/presentation/download_dialog.dart` の `_canStartDownload` ゲッターで `ref.read(currentDirectoryProvider)` を `ref.read(libraryPathProvider)` に変更する
- [x] 2.2 同ファイルの `_startDownload` メソッドで `ref.read(currentDirectoryProvider)!` を `ref.read(libraryPathProvider)!` に変更する
- [x] 2.3 既存テスト `download_dialog_test.dart` の `createTestApp()` で `libraryPathProvider` のオーバーライドを追加する（既存テストが壊れないようにする）
- [x] 2.4 全テストを実行し、パスすることを確認する
- [x] 2.5 テストがパスしたらコミットする

## 3. 最終確認

- [x] 3.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [x] 3.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 3.3 `fvm flutter analyze`でリントを実行
- [x] 3.4 `fvm flutter test`でテストを実行
