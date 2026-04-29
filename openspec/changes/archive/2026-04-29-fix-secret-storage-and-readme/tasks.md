## 1. セットアップ

- [x] 1.1 `pubspec.yaml` に `flutter_secure_storage: ^9.0.0` を追加
- [x] 1.2 `fvm flutter pub get` で依存解決
- [x] 1.3 `flutter_secure_storage` のテスト用モック方針 (`MethodChannel` モック) を `test/test_utils/` に下準備

## 2. SettingsRepository テスト先行 (TDD - red)

- [x] 2.1 `test/features/settings/data/settings_repository_test.dart` に「`getApiKey` は `flutter_secure_storage` から読み出す」テストを追加
- [x] 2.2 「`setApiKey` は `flutter_secure_storage` に書き込み、`SharedPreferences` には書き込まない」テストを追加
- [x] 2.3 「空文字列で `setApiKey` を呼ぶと secure storage 上のエントリが削除される」テストを追加
- [x] 2.4 既存の API key 関連テストを secure storage 前提に書き換え (`SharedPreferences` ベースのものは migration テスト側へ移動)
- [x] 2.5 `fvm flutter test` を実行し、追加分が **fail** することを確認 (赤コミット)

## 3. マイグレーション テスト先行 (TDD - red)

- [x] 3.1 「`SharedPreferences` に `llm_api_key` が存在する場合、`flutter_secure_storage` に転送して `SharedPreferences` から削除する」テストを追加
- [x] 3.2 「`SharedPreferences` に `llm_api_key` が無い場合、何もせず正常完了する」テストを追加
- [x] 3.3 「マイグレーション実行後の二度目呼び出しが no-op で終わる」テストを追加 (冪等性)
- [x] 3.4 「`flutter_secure_storage` 書き込みが例外を投げる場合、`SharedPreferences` エントリは温存され、関数は throw せずに完了する」テストを追加
- [x] 3.5 `fvm flutter test` を実行し、追加分が **fail** することを確認 (赤コミット)

## 4. SettingsRepository 実装 (TDD - green)

- [x] 4.1 `SettingsRepository` に `FlutterSecureStorage` フィールドを追加 (DI 可能に)
- [x] 4.2 `getApiKey` を `Future<String>` に変更し secure storage から読み出すよう実装
- [x] 4.3 `setApiKey` を `Future<void>` に変更し secure storage に書き込み、空文字列は `delete` で扱うよう実装
- [x] 4.4 `migrateApiKeyToSecureStorage()` を実装 (try/catch で書き込み例外を捕捉、`debugPrint` でログ、書き込み成功時のみ `SharedPreferences` から削除)
- [x] 4.5 セクション 2/3 のテストが全て **pass** することを確認

## 5. LlmConfig からの API key 切り離し

- [x] 5.1 「`LlmConfig` に `apiKey` フィールドが含まれない」テストを追加 (型レベル / `toJson` / `fromJson`)
- [x] 5.2 「`getLlmConfig` 戻り値に API key が含まれず、API key の取得は専用メソッドが必要」テストを追加
- [x] 5.3 テストが fail することを確認 (赤)
- [x] 5.4 `LlmConfig` から `apiKey` フィールドを削除
- [x] 5.5 `getLlmConfig` / `setLlmConfig` から API key の取り扱いを除去
- [x] 5.6 セクション 5 のテストが pass することを確認 (緑)

## 6. LLM クライアント生成箇所の on-demand 化

- [x] 6.1 LLM クライアント生成箇所を grep で洗い出し (`OpenAiCompatibleClient(`, `OllamaClient(` 全箇所)
- [x] 6.2 「`OpenAiCompatibleClient` は生成時に `SettingsRepository.getApiKey()` を await して渡される」テストを追加
- [x] 6.3 「`flutter_secure_storage` に API key が無い場合、`OpenAiCompatibleClient` 生成は null を返す (LLM 機能無効)」テストを追加
- [x] 6.4 テストが fail することを確認 (赤)
- [x] 6.5 各生成箇所 (`llm_summary_pipeline.dart` 等) で API key を on-demand 取得するように変更
- [x] 6.6 セクション 6 のテストが pass することを確認 (緑)

## 7. アプリ起動時のマイグレーション呼び出し

- [x] 7.1 「`main()` 起動シーケンスでマイグレーションが `runApp` 前に1回呼ばれる」ことを統合的に検証するテストを追加 (難しければスタートアップヘルパ関数を抽出してそれをテスト)
- [x] 7.2 「マイグレーションが例外を投げてもアプリ起動が続行する」テストを追加
- [x] 7.3 テストが fail することを確認 (赤)
- [x] 7.4 `main.dart` (または抽出した起動ヘルパ) で `runApp` 前に `SettingsRepository.migrateApiKeyToSecureStorage()` を try/catch 付きで呼び出す
- [x] 7.5 セクション 7 のテストが pass することを確認 (緑)

## 8. 設定画面 UI の追従

- [x] 8.1 `settings_dialog.dart` の API key TextField 初期化が `getApiKey()` を await するように変更
- [x] 8.2 保存処理 (`_saveLlmConfig` 等) が `setApiKey()` を await するように変更
- [x] 8.3 既存の widget テストがあれば async 化に追従、無ければ最小限の動作確認テストを追加
- [x] 8.4 ローカル起動 (`fvm flutter run`) で API key の入力 → 保存 → 再起動後も復元、を手動確認

## 9. README 修正 (F030)

- [x] 9.1 `README.md:33` の Ollama エンドポイントを `http://localhost:11334` から `http://localhost:11434` に修正
- [x] 9.2 README 内の他箇所に `11334` が残っていないか grep で確認

## 10. 最終確認

- [x] 10.1 simplifyスキルを使用してコードレビューを実施
- [x] 10.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 10.3 `fvm flutter analyze` でリントを実行
- [x] 10.4 `fvm flutter test` でテストを実行
