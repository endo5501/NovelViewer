## 1. テスト作成（TDD: Red）

- [x] 1.1 `test/` の `llm_summary_pipeline` パーサ関連テストに、`{"facts": ["fact1", "fact2"]}` が `\n` 結合された単一文字列として返り、構造化デコード成功（`isStructured: true`）扱いになるテストを追加
- [x] 1.2 `{"summary": ["s1", "s2"]}` 形式でも配列正規化が効くテストを追加（Stage-2 経路）
- [x] 1.3 要素に `- ` が既に含まれる配列（例: `{"facts": ["- a", "- b"]}`）で、二重付与されず素の `\n` 結合になるテストを追加
- [x] 1.4 空配列 `{"facts": []}` と非文字列要素混在 `{"facts": ["ok", 123]}` が `LlmResponseFormatException` で棄却され WARNING ログが出るテストを追加
- [x] 1.5 既存挙動の非回帰テストを確認（文字列値は従来どおり成功、`null`/数値/オブジェクトは棄却、非JSONは生テキストfallback）
- [x] 1.6 `fvm flutter test` を実行し、追加テストが失敗（Red）することを確認

## 2. 実装（TDD: Green）

- [x] 2.1 `lib/features/llm_summary/data/llm_summary_pipeline.dart` の `_parseJsonResponse` に、`decoded[key]` が `List` で全要素 `String` の場合に `\n` 結合して `_ParsedValue(value, isStructured: true)` を返す分岐を追加
- [x] 2.2 配列だが空、または非文字列要素を含む場合は既存の非文字列棄却パス（`LlmResponseFormatException` + WARNING ログ）へ合流させる
- [x] 2.3 `fvm flutter test` を実行し、全テストが通過（Green）することを確認

## 3. 動作確認

- [ ] 3.1 実機の Ollama + MLX モデル（例: `qwen3.8:27b-mlx`）で解析を実行し、従来失敗していたケースが成功することを確認（可能な範囲で）
- [ ] 3.2 `app.log` に `no string value; rejecting` の配列棄却ログが出なくなったことを確認

## 4. 最終確認

- [x] 4.1 code-reviewスキルを使用してコードレビューを実施
- [x] 4.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 4.3 `fvm flutter analyze`でリントを実行
- [x] 4.4 `fvm flutter test`でテストを実行
