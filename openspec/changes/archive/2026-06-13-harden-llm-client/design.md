## Context

LLMクライアントは2本ある:

- `OpenAiCompatibleClient`（`generate` のみ。`POST /chat/completions`）
- `OllamaClient`（`generate` / `releaseResources` / static `fetchModels`。`POST /api/generate`, `GET /api/tags`）

どちらも `dart:convert` の `jsonDecode(response.body)` を使い、応答形状を信頼してキャストしている。両者とも構築済みで `http.Client? httpClient` を受け取れるが、未指定時は内部で `http.Client()` を生成する。

provider 側（`llmClientProvider`、FutureProvider）は `llmConfigProvider` を watch し、設定変更のたびにクライアントを再構築するが、`httpClient` を渡していないため毎回新しい未close クライアントが作られる。共有 `httpClientProvider`（`settings_providers.dart:13`）は `onDispose` で close 済みで、他4機能が利用している。

パイプライン `LlmSummaryPipeline._parseJsonResponse`（`llm_summary_pipeline.dart:169-187`）は、(a) JSONデコード失敗時は WARNING ログ＋生テキストへフォールバック（`llm-summary-pipeline` スペックに既存要件あり）、(b) デコード成功かつキーありの場合 `decoded[key] as String` で取り出す。(b) の `as String` が `CastError` を投げると (a) の catch に落ち、生JSON文字列が要約として返り永続化される。

これらネットワークパーサにはテストが存在しない（F143）。

## Goals / Non-Goals

**Goals:**

- 応答ボディを charset 非依存で UTF-8 復号し、日本語文字化けを根絶する（F113）。
- 応答形状の不一致を型付き例外 `LlmResponseFormatException` に変換し、生の `RangeError`/`TypeError`/`CastError` を呼び出し側・UIへ漏らさない（F113）。
- 妥当JSONだがキー値が String でない応答を「壊れた応答」として扱い、生JSONの要約永続化を止める（F132）。
- LLMクライアントを `httpClientProvider` 注入に統一し、未close クライアントの量産を止める（F163）。
- 上記すべてに現挙動固定の失敗系テストを先に書く（TDD）。

**Non-Goals:**

- リトライ/バックオフ・タイムアウトの追加（F121/F144 系。別debt）。
- LLM応答スキーマの厳密バリデーション全般（必要十分な形状ガードに留める）。
- `llm-settings` / `ollama-model-list` のUI挙動変更（ドロップダウン等は不変）。
- 死にコード `generate()`（F133）の削除（別change）。

## Decisions

### D1: UTF-8 復号は `utf8.decode(response.bodyBytes)` に一本化

`response.body` は `Content-Type` の charset 無指定時 latin1 へフォールバックする（`http` パッケージの仕様）。実OpenAI互換エンドポイントは裸の `application/json` を返すため日本語が壊れる。全パースポイント（成功応答・モデル一覧・非200エラーメッセージ内のボディ）で `utf8.decode(response.bodyBytes)` を使う。

- 代替案: `response.headers['content-type']` を見て条件分岐 → 複雑で取りこぼしリスク。本アプリの相手は常にUTF-8 JSONなので一律UTF-8で十分。

### D2: 形状検証を共通ヘルパーに集約し `LlmResponseFormatException` を投げる

`lib/features/llm_summary/data/` に `LlmResponseFormatException`（`implements Exception`、説明メッセージ保持）を新設。各クライアントは「デコード→object検証→必須フィールド存在・型検証→値取得」の順で処理し、不一致時は同例外を投げる。検証の重複（top-level object チェック等）を小さなプライベートヘルパーに寄せる。

- 検証対象:
  - OpenAI `generate`: `choices` が非空 List、`choices[0].message.content` が String。
  - Ollama `fetchModels`: `models` が List、各要素が Map で `name` が String。
  - Ollama `generate`: `response` が String。
- 代替案: 既存の汎用 `throw Exception(...)` のまま → F141 の「汎用例外乱立」を助長し、UI側で種別判定できない。型付きにする。

### D3: パイプラインのキー値検証（F132）は「型不一致＝壊れた応答」として例外化

`_parseJsonResponse` を次の三分岐にする:

1. `jsonDecode` 失敗（非JSON応答）→ 既存どおり WARNING ログ＋生テキストフォールバック（モデルがプレーンテキストを返す正当なケースを維持）。
2. デコード成功＝JSON object で、キーが在り値が String → その値を返す（従来どおり）。
3. デコード成功＝JSON object だが、キー不在 or 値が非String → `LlmResponseFormatException` を投げ WARNING ログ。生JSONは返さない・保存しない。

- 「非JSON応答のフォールバックは残す／妥当JSONの形状不一致はエラーにする」という非対称が肝。前者はLLMの自由形式出力への耐性、後者はキャッシュ汚染の防止。
- 代替案A: 型不一致時に空文字を返す → UIに「空要約」が出て失敗が見えない。例外の方が診断可能。
- 代替案B: `is String` を足すだけ → fallback で結局生JSONを返すため F132 が直らない。却下。

### D4: `httpClientProvider` 注入（F163）。コンストラクタ引数は必須化しない

`llmClientProvider` 内で `final httpClient = ref.watch(httpClientProvider);` を両クライアントへ渡す。`fetchModels` 呼び出し側（`ollamaModelListProvider`）も同様に注入する。

- コンストラクタの `http.Client? httpClient`（任意）は**そのまま維持**する: テストがモック注入に使うため。production 経路（provider）が必ず注入することを spec とテストで担保する方が、API破壊を避けつつ規約を守れる。
- 代替案: 引数を必須化（`required http.Client httpClient`）→ DI規約は強制できるが全テスト・全呼び出しを一斉改修する破壊変更。本changeでは provider 注入＋テストで規律を担保し、必須化は見送る（Non-Goal）。

### D5: テストは現挙動固定（失敗系）から（TDD）

`MockClient`（`package:http/testing.dart`）で固定レスポンスを与え、まず現バグを再現するテスト（latin1文字化け／`choices: []` で RangeError／`{"summary": null}` で生JSON永続化）を書いて Red を確認 → 実装で Green にする。provider 注入は `ProviderContainer` ＋ `httpClientProvider` override で検証。

## Risks / Trade-offs

- [型不一致を例外化するとパイプライン全体が中断する] → 妥当JSONで値型が壊れている応答は実運用ではまれ。生の壊れ要約をキャッシュするより、明示エラーで再試行/中断する方が安全。fact抽出の1チャンク失敗も同様に中断扱いで許容（壊れ facts の混入を防ぐ）。
- [UTF-8固定で非UTF-8応答が来たら例外] → 相手は常にUTF-8 JSON前提。`utf8.decode` の `malformed` をどう扱うかは、既定（例外）のままで可（壊れたバイト列は形状エラーと同じく失敗が見える方が良い）。
- [`LlmResponseFormatException` の文言が長大ボディを含むと肥大] → メッセージはプレフィクスを上限付き（既存ログの200字方針に合わせる）に切る。
- [provider注入のみで必須化しない＝将来また直接 `http.Client()` を書く呼び出しが現れ得る] → spec に「production経路は注入」を明記＋テストで固定。根本のDI必須化は F124/F125 と併せた将来対応（Non-Goal）。

## Migration Plan

- データ移行なし。既存 `fact_cache` に既に焼き付いた文字化け要約は、再分析（既存の content-hash/prompt-version 無効化）で自然に上書きされる。本changeでの一括クリーンアップは行わない。
- ロールバック: 純粋なコード変更のため revert で戻る。永続スキーマ変更なし。

## Open Questions

- なし（スコープ・挙動は確定）。F104/F109/F111 等の他High項目はメンテナのOpen Question待ちで本changeのスコープ外。
