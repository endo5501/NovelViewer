## 1. インターフェース拡張（TDD: テスト先行）

- [x] 1.1 `test/features/llm_summary/data/llm_client_test.dart` に「`LlmClient` の既定 `releaseResources()` は no-op で正常完了する」テストを追加（実装はまだ書かない）
- [x] 1.2 テストを実行し、コンパイルエラー / 失敗することを確認
- [x] 1.3 `lib/features/llm_summary/data/llm_client.dart` の `LlmClient` 抽象クラスに既定 no-op 実装の `Future<void> releaseResources() async {}` を追加
- [x] 1.4 1.1 のテストが通ることを確認

## 2. OpenAI 互換クライアントの仕様確認（TDD: テスト先行）

- [x] 2.1 `test/features/llm_summary/data/llm_client_test.dart` に「`OpenAiCompatibleClient.releaseResources()` は HTTP リクエストを送らず正常完了する」テストを追加（モック `http.Client` の呼び出し回数で検証）
- [x] 2.2 テストを実行し、現状（既定 no-op を継承）で既に通ることを確認（実装変更不要であることを保証する）

## 3. Ollama クライアントの解放実装（TDD: テスト先行）

- [x] 3.1 `test/features/llm_summary/data/llm_client_test.dart` に「`OllamaClient.releaseResources()` は `POST {baseUrl}/api/generate` に `{ "model": "<model>", "keep_alive": 0 }` を `prompt` フィールドなしで送る」テストを追加（モック `http.Client` で URL/メソッド/ボディを検証）
- [x] 3.2 「サーバが非 2xx を返したら例外を投げる」テストを追加
- [x] 3.3 「`http.Client` がネットワークエラーを投げたら例外がそのまま伝播する」テストを追加
- [x] 3.4 テストを実行し失敗を確認
- [x] 3.5 `lib/features/llm_summary/data/ollama_client.dart` で `releaseResources()` をオーバーライドし、上記仕様の HTTP 呼び出しを実装
- [x] 3.6 3.1〜3.3 のテストがすべて通ることを確認

## 4. サービス層での解放呼び出し（TDD: テスト先行）

- [x] 4.1 `test/features/llm_summary/data/llm_summary_service_test.dart`（無ければ新規作成）に「生成成功時に `releaseResources()` が `await` で呼ばれてからサマリが返る」テストを追加（fake `LlmClient` で呼び出し順序を検証）
- [x] 4.2 「パイプラインが例外を投げた場合でも `releaseResources()` が呼ばれ、その後で元の例外が再 throw される」テストを追加
- [x] 4.3 「`releaseResources()` が例外を投げても、生成成功のサマリ値はそのまま返り、ユーザに見える例外にはならない」テストを追加
- [x] 4.4 「生成例外 `E1` と `releaseResources()` 例外 `E2` が両方発生した場合、呼び出し側に伝わるのは `E1` である」テストを追加
- [x] 4.5 テストを実行し失敗を確認
- [x] 4.6 `lib/features/llm_summary/data/llm_summary_service.dart` の `generateSummary()` を try/finally で包み、finally 内で `await llmClient.releaseResources()` を呼ぶ。release 自体の例外は内側 try/catch で握りつぶす
- [x] 4.7 4.1〜4.4 のテストがすべて通ることを確認

## 5. 既存テスト・統合の確認

- [x] 5.1 `test/features/llm_summary/data/llm_client_test.dart` の既存ケースが影響を受けていないことを確認
- [x] 5.2 `test/features/llm_summary/providers/llm_summary_providers_test.dart` 等で `LlmClient` をモックしているテストが既定 no-op の影響を受けていないことを確認
- [x] 5.3 既存の Ollama 関連テスト（`test/features/llm_summary/providers/ollama_model_list_provider_test.dart` 等）に副作用がないことを確認

## 6. 最終確認

- [x] 6.1 simplifyスキルを使用してコードレビューを実施
- [x] 6.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 6.3 `fvm flutter analyze`でリントを実行
- [x] 6.4 `fvm flutter test`でテストを実行
