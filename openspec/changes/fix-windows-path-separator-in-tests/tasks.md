## 1. テストコードのパス区切り文字修正

- [ ] 1.1 `test/features/text_download/novel_library_service_test.dart` に `import 'package:path/path.dart' as p;` を追加し、22行目・30行目の `'${tempDir.path}/NovelViewer'` を `p.join(tempDir.path, 'NovelViewer')` に置き換え
- [ ] 1.2 `test/features/text_search/data/text_search_service_test.dart` に `import 'package:path/path.dart' as p;` を追加し、110行目の `'${tempDir.path}/001.txt'` を `p.join(tempDir.path, '001.txt')` に置き換え

## 2. 動作確認

- [ ] 2.1 `fvm flutter test test/features/text_download/novel_library_service_test.dart` でテスト通過を確認
- [ ] 2.2 `fvm flutter test test/features/text_search/data/text_search_service_test.dart` でテスト通過を確認
- [ ] 2.3 `fvm flutter test` で全テスト通過を確認

## 3. 最終確認

- [ ] 3.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [ ] 3.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 3.3 `fvm flutter analyze`でリントを実行
- [ ] 3.4 `fvm flutter test`でテストを実行
