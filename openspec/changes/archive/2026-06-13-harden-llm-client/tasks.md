## 1. 例外型の新設

- [x] 1.1 `lib/features/llm_summary/data/llm_response_format_exception.dart` に `LlmResponseFormatException`（`implements Exception`、説明メッセージ保持、`toString` 実装）を追加
- [x] 1.2 メッセージにボディ抜粋を含める場合は上限（200字程度）で切るヘルパーを用意（`LlmResponseFormatException.withBody`、既存ログ方針と整合）

## 2. OpenAiCompatibleClient の堅牢化（F113）— テストファースト

- [x] 2.1 既存 `test/features/llm_summary/data/llm_client_test.dart` に `OpenAiCompatibleClient robustness` グループを追加（新規ファイルではなく既存集約ファイルへ。`MockClient` で現挙動を固定する失敗系テスト・Red）:
  - charset 無し UTF-8 ボディの日本語が文字化けしないこと
  - `{"choices": []}` で `LlmResponseFormatException`（現状は `RangeError`）
  - `choices[0].message.content` 欠落/非Stringで `LlmResponseFormatException`（現状 `CastError`）
  - 非200エラーのボディが UTF-8 復号されること
  - 正常応答が従来どおりの文字列を返すこと（既存テストで担保）
- [x] 2.2 `openai_compatible_client.dart` を実装: `utf8.decode(response.bodyBytes)` に統一、top-level object 検証 + `choices`/`message.content` の形状検証で `LlmResponseFormatException` を投げる（Green）

## 3. OllamaClient の堅牢化（F113）— テストファースト

- [x] 3.1 既存 `llm_client_test.dart` に `OllamaClient robustness` グループを追加（Red）:
  - `fetchModels`: UTF-8 復号、`{"models": null}` で `LlmResponseFormatException`（現状 `TypeError`）、各要素の `name` 非Stringで例外、`{"models": []}` は空リスト（既存テストで担保）
  - `generate`: `response` 非String/欠落で `LlmResponseFormatException`、正常時は文字列、非200エラーのボディ UTF-8 復号
- [x] 3.2 `ollama_client.dart` を実装: 全パースポイントを `utf8.decode(response.bodyBytes)` に統一（`_decodeOk` ヘルパー）、`models`/`name`/`response` の形状検証で `LlmResponseFormatException`（Green）

## 4. パイプラインのキー値検証（F132）— テストファースト

- [x] 4.1 既存 `llm_summary_pipeline_test.dart` に Red テストを追加:
  - 非JSON応答 → 既存どおり生テキストフォールバック（既存テストで維持確認）
  - `{"summary": null}` → 生JSONを返さず `LlmResponseFormatException`（現状は生JSON文字列を返す）
  - キー不在の妥当JSON object → `LlmResponseFormatException`
  - キーありString値 → その値を返し、ログ・例外なし（既存テストで担保）
- [x] 4.2 `_parseJsonResponse` を design D3 の三分岐に実装: デコード失敗はフォールバック維持、object かつ String 値は返す、object だがキー不在/非Stringは `LlmResponseFormatException`＋WARNINGログ（Green）

## 5. HTTPクライアント注入（F163）— テストファースト

- [x] 5.1 `llm_summary_providers_test.dart` で、`ProviderContainer` ＋ `httpClientProvider` override により `llmClientProvider` が生成するクライアント（OpenAI/Ollama両方）が override 済みクライアント経由で通信することを検証する Red テストを追加
- [x] 5.2 `llm_summary_providers.dart` の `llmClientProvider` で `ref.watch(httpClientProvider)` を両クライアントへ注入。`ollamaModelListProvider` は調査の結果**既に注入済み**だったため変更不要。これで production 経路の内部 `http.Client()` 生成を排除（Green）

## 6. 最終確認

- [x] 6.1 code-reviewスキルを使用してコードレビューを実施（指摘: 非UTF-8エラーボディで`utf8.decode`が`FormatException`→`allowMalformed:true`で修正＋回帰テスト追加）
- [x] 6.2 codexスキルを使用して現在開発中のコードレビューを実施（correctness指摘なし）
- [x] 6.3 `fvm flutter analyze`でリントを実行（No issues found）
- [x] 6.4 `fvm flutter test`でテストを実行（2034件パス）
- [x] 6.5 `TECH_DEBT_AUDIT.md` の F113(✅) / F132(✅) / F163(🟡一部) を更新し、Quick wins チェックリストの F113/F132 をチェック
