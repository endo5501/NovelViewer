## 1. テスト修正

- [ ] 1.1 `test/features/settings/presentation/llm_settings_test.dart` の "changing provider updates displayed fields" テストで、ドロップダウンをタップする前に `await tester.ensureVisible(find.text('未設定'))` を追加して LLM プロバイダドロップダウンを表示領域内にスクロールさせる
- [ ] 1.2 ドロップダウン展開後の 'Ollama' アイテム選択が正常に動作することを確認し、必要であれば `find.text('Ollama').last` の代替ファインダーに変更する

## 2. 検証

- [ ] 2.1 `fvm flutter test test/features/settings/presentation/llm_settings_test.dart` で修正したテストが通ることを確認
- [ ] 2.2 `fvm flutter test` で全テストが通ることを確認（既存テストにリグレッションがないこと）

## 3. 最終確認

- [ ] 3.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [ ] 3.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 3.3 `fvm flutter analyze`でリントを実行
- [ ] 3.4 `fvm flutter test`でテストを実行
