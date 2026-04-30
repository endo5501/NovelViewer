## Why

Ollama を使って LLM 要約を行うと、生成完了後もモデルが GPU メモリにロードされたまま 5 分間保持される（Ollama デフォルトの `keep_alive` 仕様）。NovelViewer の要約機能は単発で短時間に集中して使う性質のため、生成完了直後に GPU を解放したほうがユーザの GPU リソースを早く返却でき、他の作業を圧迫しない。

## What Changes

- `LlmClient` インターフェースに「LLM 側に保持されたリソースを解放する」既定 no-op の API を追加する。
- `OllamaClient` でその API を実装し、要約完了後に Ollama 側のモデルアンロード（`keep_alive=0`）を明示的に要求する。
- `LlmSummaryService.generateSummary()` の終端で必ずリソース解放 API を呼び出す（成功/失敗いずれの場合も解放を試みる）。
- 解放呼び出し自体の失敗はユーザに見せず、握りつぶす（最悪でも Ollama デフォルトの 5 分タイムアウトで解放されるため、ユーザに影響しない）。
- OpenAI 互換クライアントは既定実装（no-op）のまま使うため、振る舞いの変化はない。
- 設定 UI への露出はしない（固定挙動）。

## Capabilities

### New Capabilities
（なし）

### Modified Capabilities
- `llm-settings`: LLM クライアント抽象に「使用後リソース解放」の責務を追加し、Ollama クライアントの解放挙動を仕様化する。
- `llm-summary-pipeline`: 要約処理（サービス層）が生成完了後に LLM クライアントのリソース解放を呼び出す責務を仕様化する。

## Impact

- 影響コード:
  - `lib/features/llm_summary/data/llm_client.dart`（インターフェース拡張）
  - `lib/features/llm_summary/data/ollama_client.dart`（解放実装の追加）
  - `lib/features/llm_summary/data/llm_summary_service.dart`（finally で解放呼び出し）
  - `lib/features/llm_summary/data/openai_compatible_client.dart`（変更なし／既定 no-op を使用）
- API: Ollama サーバへ `POST /api/generate` に `{ "model": "<model>", "keep_alive": 0, "stream": false }` を `prompt` 省略で送信する 1 リクエストが追加される。
- 依存関係: 追加なし。
- ユーザ可視の振る舞い変化: なし（要約結果と UI は同一。スピナー表示時間が解放往復分だけわずかに長くなる）。
