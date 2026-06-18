## 1. テスト作成（失敗確認）

- [x] 1.1 `test/features/file_browser/presentation/file_browser_panel_test.dart` に、フォルダタイルが `displayName` を `message` とする `Tooltip` でラップされていることを検証するテストを追加する
- [x] 1.2 同テストに、ファイルタイルが `name` を `message` とする `Tooltip` でラップされていることを検証するテストを追加する
- [x] 1.3 同テストに、選択中のファイルタイルでも `Tooltip`（`message` = ファイル名）が存在し、選択装飾（`selected_file_tile_decoration`）が維持されることを検証するテストを追加する
- [x] 1.4 `fvm flutter test` を実行し、追加したテストが失敗することを確認する
- [x] 1.5 失敗するテストをコミットする

## 2. 実装

- [x] 2.1 `_buildDirectoryTile` のタイトル `Text(dir.displayName, ...)` を `Tooltip(message: dir.displayName, child: Text(...))` でラップする
- [x] 2.2 `_buildFileTile` のタイトル `Text(file.name, ...)` を `Tooltip(message: file.name, child: Text(...))` でラップする（選択装飾の `Container` 分岐より内側、`Text` の直上に置く）
- [x] 2.3 `fvm flutter test` を実行し、1章で追加したテストが通過することを確認する

## 3. 最終確認

- [x] 3.1 code-reviewスキルを使用してコードレビューを実施
- [x] 3.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 3.3 `fvm flutter analyze`でリントを実行
- [x] 3.4 `fvm flutter test`でテストを実行
