## 1. テスト作成（TDD: 先にテスト、失敗を確認してからコミット）

- [x] 1.1 `OllamaClient.generate` のリクエストボディに `"think": false` と `"options": {"num_predict": 1024}` が含まれることを検証するテストを `test/features/llm_summary/data/ollama_client_test.dart`（既存があれば追記）に作成
- [x] 1.2 `releaseResources` のボディに `think` / `options` が含まれないこと（`keep_alive: 0` のみ）を検証するテストを作成
- [x] 1.3 フォールバックのテストを作成: (a) 非200かつ本文に `think` を含むエラーで `think` なしの再送が1回だけ行われ成功レスポンスが返る、(b) フォールバック後の同一インスタンスの `generate` は最初から `think` なしで1回だけ送信される、(c) 本文に `think` を含まない非200エラーは再送なしでそのまま伝播する
- [x] 1.4 テストを実行して失敗（red）を確認し、テストのみをコミット

## 2. 実装

- [x] 2.1 `lib/features/llm_summary/data/ollama_client.dart` の `generate` に `think: false`・`options.num_predict`（static const、値1024）を追加し、think起因エラー時の1回フォールバック＋以後 `think` 省略のインスタンス状態を実装
- [x] 2.2 テストを実行して全テストがパス（green）することを確認

## 3. 実機確認

- [ ] 3.1 ローカルOllama（thinking対応モデル）で用語解析を実行し、従来より大幅に短縮されること・要約品質が同等であることを確認
- [ ] 3.2 thinking非対応モデル（例: qwen2.5:14b-instruct）でもエラーなく解析が完了することを確認

## 4. 最終確認

- [ ] 4.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 4.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 4.3 `fvm flutter analyze`でリントを実行
- [ ] 4.4 `fvm flutter test`でテストを実行
