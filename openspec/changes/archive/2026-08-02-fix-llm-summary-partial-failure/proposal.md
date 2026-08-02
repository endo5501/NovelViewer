## Why

用語解析が途中で中断し、成果物ゼロで終わるケースが 2026-08-01 以降に増加した。ログ調査により原因が特定できた。

`speed-up-llm-summary`（2026-08-02）で `think: false` を付与した結果、thinking対応モデルが内部で行っていた出力整形が失われ、LLMがJSONの形を崩すようになった。実測されている崩れ方は2種類:

| 種別 | 応答例 | 現在の挙動 |
|---|---|---|
| A: 文字列内の `"` を未エスケープ | `{"facts": "- "ダプラ" is a status..."` | `jsonDecode` 失敗 → 生テキストをfactsとして採用・**キャッシュに保存** |
| B: 値を配列で返す | `{"facts": ["- ...", "- ..."]}` | `LlmResponseFormatException` を throw → **解析全体が中断** |

種別Bは `harden-llm-client`（2026-06-13, F132）で「JSONだが値が文字列でない」を例外化した際に埋まった経路で、当時は thinking が整形を担保していたため踏まれなかった。`think: false` との合流で顕在化した。

加えて、種別Aの生テキストフォールバックは `{"facts": "- ...` というJSONの残骸をそのまま `fact_cache` に書き込んでおり、`prompt_version` が変わるまで以後の解析入力を汚染し続ける（実測で空応答 `length=0` を空factsとして保存した事例もある）。

現状はどの経路でも「1ファイルの失敗＝全ファイルの作業が無駄」になる。Ollamaは Structured Outputs（`format` にJSONスキーマ）を 0.5.0 以降で提供しており、実質全ユーザーが対応バージョンを利用しているため、整形ミス自体を文法制約で根絶できる。その上で、残る一過性エラーをリトライと部分継続で吸収する。

## What Changes

**① 構造化出力の強制（整形ミスの根絶）**

- `LlmClient.generate` に応答スキーマを渡す任意引数を追加する
- `OllamaClient` はそれを `POST /api/generate` の `format` フィールド（JSONスキーマ）として無条件に送信する。Stage-1 は `{"facts": <string>}`、Stage-2 は `{"summary": <string>}` を要求する
- 旧バージョン向けフォールバックは設けない（`format` スキーマ対応は Ollama 0.5.0 以降＝2024-12 以降の全バージョン）
- `OpenAiCompatibleClient` はスキーマ引数を無視する（挙動不変。プロバイダ依存のため別変更で検討）
- `releaseResources` は対象外

**② リトライ（一過性エラーの吸収）**

- Stage-1 の各ファイル、および Stage-2 の最終要約について、`generate` が失敗した場合に**同一リクエストで1回だけ**再試行する
- 整形ミスは①で発生しなくなるため、プロンプトや `think` を変更した再試行は行わない（対象はネットワーク瞬断・Ollama 5xx 等の一過性障害）

**③ キャッシュ書き込みゲート（汚染の遮断）**

- 構造化パースに成功した facts のみを `fact_cache` に `upsert` する
- 生テキストフォールバックの結果、および空文字の facts はキャッシュに書き込まない → 次回解析で自動的に再抽出される
- 既存の汚染行に対する移行処理は行わない（全期間で5行程度と少なく、再解析で自然に解消するため）

**④ 部分継続と明示的失敗**

- Stage-1 でファイル単位の抽出が（リトライ後も）失敗した場合、そのファイルを記録して**残りのファイルの抽出を継続する**（成功分をキャッシュに残し、再実行時のコストを下げるため）
- 1件でも失敗が記録された場合、Stage-2 の最終要約は**呼び出さず**、スナップショットも保存せず、解析を失敗として終了する
- スナックバーに失敗件数を含むメッセージを表示する（l10n 3言語）
- facts が空のまま Stage-2 を呼び出して幻覚的な要約を生成・保存する既存経路を塞ぐ

**⑤ 再解析時のキャッシュ無効化の精緻化**

- 再解析（同一 `coveredUpToEpisode` のスナップショットが既存）で `invalidateWord` を行う際、`fact_cache.updated_at` が当該スナップショットの `updated_at` より新しい行は「先行する失敗試行で既に再抽出済み」とみなし、無効化の対象外とする
- これがないと、再解析が失敗するたびに直前の試行で温めたキャッシュが破棄され、再実行が毎回フルコストになる

## Capabilities

### New Capabilities

<!-- なし: 既存capabilityへの要件追加・変更で表現できる -->

### Modified Capabilities

- `llm-client-robustness`: `LlmClient.generate` のスキーマ引数と、`OllamaClient` による `format` スキーマ送信を要件として追加する（応答形状の検証を「受信後の拒否」から「生成時の制約」へ前倒しする）
- `llm-summary-pipeline`: Stage-1/Stage-2 のリトライ、ファイル単位失敗時の継続、空 facts での最終要約生成の禁止を追加し、既存の「JSON decode failure observability」における生テキストフォールバックの扱いを、キャッシュ書き込み対象外とする方向に更新する
- `llm-summary-fact-cache`: 構造化パースに成功した facts のみを永続化する書き込み条件を追加する
- `llm-summary`: 「Re-analysis forces fresh fact extraction」に、先行する失敗試行で更新済みの行を無効化対象から除外する規則を追加する
- `llm-summary-context-menu-trigger`: 解析完了時のスナックバーに、スキップされたファイル件数を伝える失敗メッセージを追加する

## Impact

- 影響コード:
  - `lib/features/llm_summary/data/llm_client.dart`（`generate` シグネチャ）
  - `lib/features/llm_summary/data/ollama_client.dart`（`format` 付与）
  - `lib/features/llm_summary/data/openai_compatible_client.dart`（引数追加のみ、挙動不変）
  - `lib/features/llm_summary/data/llm_summary_pipeline.dart`（リトライ、空 facts ガード、パース結果の成否伝達）
  - `lib/features/llm_summary/data/llm_summary_service.dart`（ファイル単位の失敗継続、書き込みゲート、再解析時の無効化条件）
  - `lib/features/llm_summary/data/fact_cache_repository.dart`（`invalidateWord` の条件付き化）
  - `lib/features/llm_summary/presentation/analysis_runner.dart` および `lib/l10n/`（スナックバー文言）
- 影響なし: プロンプト文面（不変のため `fact_cache.prompt_version` は据え置き）、DBスキーマ（`updated_at` は両表に既存）、設定UI、TTS系
- 外部依存: Ollama の `format` パラメータ（JSONスキーマ形式、0.5.0 以降）
- 期待効果: 整形ミス起因の中断が原理的に消滅し、残る一過性障害もリトライで吸収される。それでも失敗した場合、成功済みファイルのキャッシュは保持され、再実行は失敗ファイル分のみのコストで済む

## 明示的なスコープ外

- `format` 非対応バージョン向けのフォールバック（対象ユーザーが存在しない）
- `done_reason: "length"` による打ち切り検知（実測の応答本文は最大167トークンで、上限1024に対し約6倍の余裕がある）
- `options.num_predict` の値変更
- 既存の汚染キャッシュ行に対する移行・掃除処理
- `fact_cache.prompt_version` のbump
- スナップショットへの「欠落あり」情報の永続化と履歴詳細画面での表示
- `OpenAiCompatibleClient` の `response_format` 対応
