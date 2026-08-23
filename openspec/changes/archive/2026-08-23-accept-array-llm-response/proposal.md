## Why

Ollama の MLX ランナー（例: `qwen3.8:27b-mlx`）は `/api/generate` の `format`（JSON スキーマによる構造化出力）を無視するため、大きく賢いモデルほど、プロンプトが例示した `{"facts": "文字列"}` を「箇条書きなら配列が正しい」と判断して `{"facts": ["事実1", "事実2"]}` の形で返す。現在のパイプラインは値が文字列であることを必須とし（`llm_summary_pipeline.dart` の `decoded[key] is String` 判定）、配列を「非文字列＝不正」として `LlmResponseFormatException` で棄却するため、内容自体は正しいのに解析全体が失敗する。小型モデル（`gemma3n:e4b`）はプロンプト例を素直に文字列でコピーするため成功し、「大きいモデルほど失敗する」という逆転現象が起きている。

`format` の強制はランナー実装（MLX か GGUF か）に依存して当てにならないため、パーサ側でこの正当な内容を受理できるようにする。

## What Changes

- Stage-1 (`facts`) / Stage-2 (`summary`) の JSON パース（`_parseJsonResponse`）で、要求キーの値が **文字列の配列** の場合、各要素を箇条書き行として `\n` 結合し、単一文字列に正規化して受理する。
- 正規化された配列レスポンスは、文字列レスポンスと同様に「構造化デコード成功（`isStructured: true`）」として扱い、既存のキャッシュ書き込みポリシー（`llm-summary-fact-cache`）に乗せる。
- 配列だが要素に文字列以外が混ざる、または空配列など、箇条書きとして意味をなさないケースは従来どおり `LlmResponseFormatException` で棄却する（不正な構造を無条件に受理はしない）。
- `null`・数値・オブジェクト（配列以外の非文字列値）に対する既存の棄却挙動は維持する。

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `llm-summary-pipeline`: 「JSON decode failure observability」requirement を変更する。要求キーの値が「文字列の配列」の場合を不正扱いにせず、箇条書き文字列へ正規化して受理する規定を追加する（現状は配列を含む全ての非文字列値を一律棄却）。

## Impact

- コード: `lib/features/llm_summary/data/llm_summary_pipeline.dart`（`_parseJsonResponse` の分岐追加）
- テスト: `test/` 配下の `llm_summary_pipeline` パーサ関連テスト（配列正規化・不正配列棄却のケース追加）
- 依存する仕様: `llm-summary-fact-cache`（正規化結果を構造化成功としてキャッシュ可能とする点で整合が必要）
- 挙動変更: MLX 系を含む「配列で返すモデル」で解析が成功するようになる。文字列で返す既存モデルの挙動は不変。
