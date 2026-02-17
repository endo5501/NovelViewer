## 1. NovelLibraryService の Windows ポータブル対応

- [x] 1.1 `NovelLibraryService.resolveLibraryPath()` に Windows 分岐を追加するテストを作成（Windows では `Platform.resolvedExecutable` の親ディレクトリ + `/NovelViewer/` を返すことを検証）
- [x] 1.2 `NovelLibraryService.resolveLibraryPath()` を修正し、Windows の場合は exe ディレクトリ基準のパスを返すように実装

## 2. NovelDatabase の Windows ポータブル対応

- [x] 2.1 `NovelDatabase._open()` に Windows 分岐を追加するテストを作成（Windows では `Platform.resolvedExecutable` の親ディレクトリに `novel_metadata.db` を配置することを検証）
- [x] 2.2 `NovelDatabase._open()` を修正し、Windows の場合は exe ディレクトリに DB を配置するように実装

## 3. 動作確認

- [x] 3.1 `fvm flutter run` で Windows 上でアプリを起動し、DB とテキストファイルが exe と同じディレクトリ配下に作成されることを確認（手動確認）

## 4. 最終確認

- [x] 4.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [x] 4.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 4.3 `fvm flutter analyze`でリントを実行
- [x] 4.4 `fvm flutter test`でテストを実行
