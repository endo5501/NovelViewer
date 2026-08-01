## Why

LLM用語要約が遅い（実測: 7ファイルヒットの用語で合計128.4秒）。実測により、時間の88%がOllamaのトークン生成であり、その大半はthinking対応モデル（gemma4等）がデフォルトで生成する思考トークン（返答には含まれず捨てられる）に費やされていることが判明した。リクエストに `think: false` を付与するだけで同一条件で128.4秒→34.0秒（3.8倍）となることを検証済み。now: 要約品質は同等のまま、1行相当の変更で最大の高速化が得られるため。

## What Changes

- `OllamaClient.generate` のリクエストボディに `think: false` を追加し、thinking対応モデルの思考トークン生成を無効化する（実測3.8倍の高速化）
- `OllamaClient.generate` のリクエストボディに `options: {"num_predict": <上限>}` を追加し、出力トークン数に上限を設けて暴走的な長出力（実測で最大1437トークン）を防止する
- 古いOllamaバージョンが `think` パラメータでエラーを返す場合に備え、該当エラー時は `think` なしで1回だけ再試行するフォールバックを設ける
- `releaseResources`（アンロード要求）は生成パラメータの対象外（変更なし）
- OpenAI互換クライアント、設定UI、パイプライン構造は変更しない（スコープ外）

## Capabilities

### New Capabilities
- `llm-generation-efficiency`: Ollamaへの生成リクエストに付与する効率化パラメータ（thinking無効化・出力トークン上限）と、旧バージョン互換のためのフォールバック挙動

### Modified Capabilities

<!-- なし: 既存capabilityの要件変更はない。llm-client-robustness（デコード・検証・DI）や llm-summary-pipeline（チャンク分割・プロンプト構成）の既存要件はそのまま維持される -->

## Impact

- 影響コード: `lib/features/llm_summary/data/ollama_client.dart`（`generate` のリクエストボディ）およびそのテスト
- 影響なし: `openai_compatible_client.dart`、`llm_summary_pipeline.dart`、プロンプト文面、`fact_cache` の `prompt_version`（プロンプト文面は不変のためキャッシュは引き続き有効）
- 外部依存: Ollama API の `think` パラメータ（thinking非対応モデルに送ってもエラーにならないことを現行バージョンで確認済み。旧バージョン向けにフォールバックで対応）
- 期待効果: 用語解析の合計時間が約1/4（thinking対応モデル使用時）。非対応モデルでは `num_predict` の保険効果のみで劣化なし
