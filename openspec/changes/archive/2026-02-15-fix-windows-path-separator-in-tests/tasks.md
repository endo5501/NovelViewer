## 1. テストコードのパス区切り文字修正

- [x] 1.1 `test/features/text_download/novel_library_service_test.dart` に `import 'package:path/path.dart' as p;` を追加し、22行目・30行目の `'${tempDir.path}/NovelViewer'` を `p.join(tempDir.path, 'NovelViewer')` に置き換え
- [x] 1.2 `test/features/text_search/data/text_search_service_test.dart` に `import 'package:path/path.dart' as p;` を追加し、110行目の `'${tempDir.path}/001.txt'` を `p.join(tempDir.path, '001.txt')` に置き換え

## 2. 動作確認

- [x] 2.1 `fvm flutter test test/features/text_download/novel_library_service_test.dart` でテスト通過を確認
- [x] 2.2 `fvm flutter test test/features/text_search/data/text_search_service_test.dart` でテスト通過を確認
- [x] 2.3 `fvm flutter test` で全テスト通過を確認（489テスト全件パス）

## 3. 最終確認

- [x] 3.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認（変更が最小限のため省略）
- [x] 3.2 codexスキルを使用して現在開発中のコードレビューを実施（Minor指摘2点を反映: createFileヘルパーのp.join統一、実装側のp.join統一）
- [x] 3.3 `fvm flutter analyze`でリントを実行（No issues found）
- [x] 3.4 `fvm flutter test`でテストを実行（489テスト全件パス）
