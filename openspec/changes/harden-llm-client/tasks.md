## 1. 例外型の新設

- [ ] 1.1 `lib/features/llm_summary/data/llm_response_format_exception.dart` に `LlmResponseFormatException`（`implements Exception`、説明メッセージ保持、`toString` 実装）を追加
- [ ] 1.2 メッセージにボディ抜粋を含める場合は上限（200字程度）で切るヘルパーを用意（既存ログ方針と整合）

## 2. OpenAiCompatibleClient の堅牢化（F113）— テストファースト

- [ ] 2.1 `test/features/llm_summary/data/openai_compatible_client_test.dart` を新設し、`MockClient`(`package:http/testing.dart`) で現挙動を固定する失敗系テストを書く（Red）:
  - charset 無し UTF-8 ボディの日本語が文字化けしないこと
  - `{"choices": []}` で `LlmResponseFormatException`（現状は `RangeError`）
  - `choices[0].message.content` 欠落/非Stringで `LlmResponseFormatException`（現状 `CastError`）
  - 非200エラーのボディが UTF-8 復号されること
  - 正常応答が従来どおりの文字列を返すこと
- [ ] 2.2 `openai_compatible_client.dart` を実装: `utf8.decode(response.bodyBytes)` に統一、top-level object 検証 + `choices`/`message.content` の形状検証で `LlmResponseFormatException` を投げる（Green）

## 3. OllamaClient の堅牢化（F113）— テストファースト

- [ ] 3.1 `test/features/llm_summary/data/ollama_client_test.dart` を新設し、失敗系テストを書く（Red）:
  - `fetchModels`: UTF-8 復号、`{"models": null}` で `LlmResponseFormatException`（現状 `TypeError`）、各要素の `name` 非Stringで例外、`{"models": []}` は空リスト（既存 `ollama-model-list` 挙動維持）
  - `generate`: `response` 非String/欠落で `LlmResponseFormatException`、正常時は文字列、非200エラーのボディ UTF-8 復号
- [ ] 3.2 `ollama_client.dart` を実装: 全パースポイントを `utf8.decode(response.bodyBytes)` に統一、`models`/`name`/`response` の形状検証で `LlmResponseFormatException`（Green）

## 4. パイプラインのキー値検証（F132）— テストファースト

- [ ] 4.1 `test/features/llm_summary/data/llm_summary_pipeline_test.dart`（既存があれば追記）に Red テストを追加:
  - 非JSON応答 → 既存どおり WARNING ログ＋生テキストフォールバック（維持）
  - `{"summary": null}` → 生JSONを返さず `LlmResponseFormatException`（現状は生JSON文字列を返す）
  - キー不在の妥当JSON object → `LlmResponseFormatException`
  - キーありString値 → その値を返し、ログ・例外なし
- [ ] 4.2 `_parseJsonResponse` を design D3 の三分岐に実装: デコード失敗はフォールバック維持、object かつ String 値は返す、object だがキー不在/非Stringは `LlmResponseFormatException`＋WARNINGログ（Green）

## 5. HTTPクライアント注入（F163）— テストファースト

- [ ] 5.1 `test/features/llm_summary/providers/llm_summary_providers_test.dart`（または相当）で、`ProviderContainer` ＋ `httpClientProvider` override により `llmClientProvider` が生成するクライアントが override 済みクライアントを使うことを検証する Red テストを書く
- [ ] 5.2 `llm_summary_providers.dart` の `llmClientProvider` で `ref.watch(httpClientProvider)` を両クライアントへ注入。`ollamaModelListProvider` 経由の `fetchModels` 呼び出しにも共有クライアントを注入し、内部 `http.Client()` 生成の production 経路を排除（Green）

## 6. 最終確認

- [ ] 6.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 6.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 6.3 `fvm flutter analyze`でリントを実行
- [ ] 6.4 `fvm flutter test`でテストを実行
- [ ] 6.5 `TECH_DEBT_AUDIT.md` の F113 / F132 / F163 を ✅ 対応済みに更新し、Quick wins チェックリストの該当行をチェック
