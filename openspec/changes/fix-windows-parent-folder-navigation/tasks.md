## 1. テストの作成（TDD: Red phase）

- [x] 1.1 `_navigateToParent()` のロジックを抽出したヘルパー関数（またはテスト可能な形）に対して、Unixパス（例: `/home/user/novels/book1`）で親ディレクトリが正しく返されるテストを作成
- [x] 1.2 Windowsパス（例: `C:\Users\name\novels\book1`）で親ディレクトリが正しく返されるテストを作成
- [x] 1.3 ルートディレクトリ（`/` や `C:\`）の場合にそれ以上遡らないことを確認するテストを作成
- [x] 1.4 テストを実行し、失敗することを確認

## 2. 実装（TDD: Green phase）

- [x] 2.1 `file_browser_panel.dart` の `_navigateToParent()` メソッドで `currentDir.substring(0, currentDir.lastIndexOf('/'))` を `p.dirname(currentDir)` に置き換え
- [x] 2.2 ルートディレクトリ判定を `parent.isNotEmpty` から `parent != currentDir` に変更
- [x] 2.3 `path` パッケージのインポートが存在することを確認（なければ追加）

## 3. 最終確認

- [x] 3.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [x] 3.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 3.3 `fvm flutter analyze`でリントを実行
- [x] 3.4 `fvm flutter test`でテストを実行
