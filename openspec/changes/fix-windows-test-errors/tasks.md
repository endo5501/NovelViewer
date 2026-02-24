## 1. tts_model_download_service_test.dart の修正

- [ ] 1.1 `import 'package:path/path.dart' as p;` を追加
- [ ] 1.2 `resolveModelsDir` テスト（line 26）の期待値を `p.join('/Users/test/Documents', 'models')` に変更

## 2. tts_model_download_providers_test.dart の修正

- [ ] 2.1 `import 'package:path/path.dart' as p;` を追加
- [ ] 2.2 `modelsDirectoryPathProvider` テスト（line 41）の期待値を `p.join(tempDir.path, 'models')` に変更
- [ ] 2.3 `download transitions to completed and auto-sets model dir` テスト（line 118）の期待値を `p.join(tempDir.path, 'models')` に変更
- [ ] 2.4 `completed state includes models directory path` テスト（line 183）の期待値を `p.join(tempDir.path, 'models')` に変更

## 3. tts_model_download_ui_test.dart の修正

- [ ] 3.1 `import 'package:path/path.dart' as p;` を追加
- [ ] 3.2 `shows completed status when models already exist` テスト（line 72）の `find.text` の期待値パスを `p.join(tempDir.path, 'models')` で構築するように変更
- [ ] 3.3 `auto-fills model directory after download` テスト（line 134-137）の `find.widgetWithText` と `controller.text` の期待値パスを `p.join(tempDir.path, 'models')` で構築するように変更

## 4. 最終確認

- [ ] 4.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [ ] 4.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 4.3 `fvm flutter analyze`でリントを実行
- [ ] 4.4 `fvm flutter test`でテストを実行
