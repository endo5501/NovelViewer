## Why

Stage-1 の事実キャッシュ (`fact_cache`) は、どのモデルがその事実を書いたかを記録していない。有効性の判定に使うのは本文のハッシュとプロンプト版だけで、抽出したモデルは問われない。

以前は実害が小さかった。プロバイダは読者が立てたサーバのモデルだけで、ollama と OpenAI 互換の違いはあっても質に段差はなく、切り替えも稀だったからである。

オンデバイス (Apple Foundation Models) が三つ目のプロバイダとして入り、その前提が崩れた。3B 級・窓 4096 トークン・戦闘描写を拒否するモデルと、サーバ上の大きなモデルとでは事実の質が段差になる。しかも切り替えは稀ではない。オンデバイスを選ぶ動機 (本文を端末から出さない) とサーバを選ぶ動機 (ガードレールを回避する、質が高い) は両立しないので、読者は行き来する。

その結果、いま起きうるのはこうである。オンデバイスで 30 話まで解析し、読み進めて 40 話でサーバに切り替えてもう一度聞く。1〜30 話分の事実は 3B モデルが書いたものがキャッシュから再利用され、31〜40 話分だけが大きなモデルで抽出される。要約はこの混ざった事実束から作られるが、読者には「サーバのモデルで解析した」としか見えない。逆向き (サーバ由来の事実をオンデバイスの実行が使う) も同様に起きる。

同一話数での再解析だけはキャッシュの無効化が走るため救われるが、読み進めながらの解析には効かず、読者がその逃げ道を知っている必要もある。

## What Changes

- `fact_cache` の一意キーを `(word, file_name)` から `(word, file_name, model_id)` に変更する。モデルごとに独立した棚を持ち、ひとつの解析実行は自分の棚だけを読む。混在は「起きないように気をつける」ものではなく、構造的に起きなくなる。
- `LlmClient` に自分を名乗る `modelId` を追加する。既定値は置かない。既定があると別のモデルが同じ棚を共有してしまい、黙って壊れるからである。`maxChunkSize` と同じく「モデルの性質はクライアントが持つ」方針に揃える。
- `FactCacheRepository` の `find` / `upsert` / `invalidateWord` が `modelId` を受け取るようにする。`deleteAllForWord` は語のすべての棚を消す (カスケードなので現状のまま)。
- 再解析時の強制無効化を、現在のモデルの棚だけに絞る。再解析は「今のモデルが出した結果が悪いからやり直す」という意思表示であり、他の棚は無関係の作業である。
- **BREAKING (データ)**: `novel_data.db` をバージョン 2 に上げ、このDBにとって初めての `onUpgrade` を通す。移行前から存在する行はどのモデルが書いたか分からないため、名乗りのない行として残さず削除する。名乗りが鍵に入る以上、そうした行はどのクライアントからも引かれず upsert でも置換されないので、キャッシュ行ではなく残骸になる。読者から見ると、次にその語を解析したときに全ファイルが抽出し直しになる。これは `prompt_version` を上げたときに起きることと同じで、既存の仕組みが前提としているコストである。
- 履歴の詳細ダイアログ「事実」タブに、行ごとの `model_id` をバッジで表示する。棚が分かれると同じファイル名が複数並ぶため、由来が見えないと区別できない。

スコープ外とするもの:

- 出力言語も同じ形の穴 (日本語で抽出した事実が英語の実行で再利用される) だが、UI 言語の切り替えは頻繁ではないという判断で今回は含めない。
- 使わなくなったモデルの棚を掃除する経路は設けない。語ごとの削除と小説ごとの削除では消える。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `llm-summary-fact-cache`: キャッシュの鍵にモデルの名乗りが加わる。有効性判定・センチネル無効化・カスケード削除の各要件がモデル単位になる。クライアントが自分を名乗る要件を新設する。
- `llm-summary`: 再解析時の強制無効化の範囲を、現在のモデルの棚に限定する。
- `per-novel-folder-database`: `fact_cache` の一意キーが 3 列になる。`novel_data.db` にバージョン移行の経路が生まれる。
- `llm-summary-history-detail-view`: 「事実」タブがモデルの名乗りを表示し、同一ファイルが棚ごとに複数行並びうる。
- `db-schema-test-fidelity`: 本番昇格パス経由で移行を検証する要件を `novel_data.db` にも及ぼす。

## Impact

コード:

- `lib/features/llm_summary/data/llm_client.dart` — `modelId` の追加 (抽象)
- `lib/features/llm_summary/data/ollama_client.dart` / `openai_compatible_client.dart` / `foundation_models_client.dart` — 名乗りの実装
- `lib/features/llm_summary/data/fact_cache_repository.dart` — 各メソッドの `modelId` 対応
- `lib/features/llm_summary/data/llm_summary_service.dart` — キャッシュ参照・書き戻し・無効化への受け渡し
- `lib/features/llm_summary/domain/fact_cache_entry.dart` — `modelId` フィールドの追加 (有効性判定は変更しない。参照が名乗りで絞られる以上、そこで重ねて見る必要がない)
- `lib/shared/database/novel_data_database.dart` — スキーマ v2、`onUpgrade`、降格の拒否、そしてこのDBを開く唯一の入口
- `lib/shared/database/database_opener.dart` — `onDowngrade` の受け渡し (他のDBは未指定のままなので挙動は変わらない)
- `lib/features/novel_metadata_db/data/novel_data_migrator.dart` — `fact_cache` のコピーを除去し、移送先をアプリ本体と同じ入口で開く
- `lib/features/llm_summary/presentation/llm_summary_detail_dialog.dart` — バッジ表示と、同一ファイル名の並べ替え鍵 (名乗りをそのまま出すので新しい l10n キーは不要)
- `lib/features/llm_summary/presentation/outlined_text_badge.dart` — 長い名乗りで隣を押し出さないよう省略表示にする

テスト: `LlmClient` を `implements` している偽クライアントは `modelId` 未実装でコンパイルが通らなくなる。黙って既定値に落ちるより良い壊れ方として受け入れる。

データ: 既存の `fact_cache` 行は移行時に削除され、次回解析で再抽出される。要約 (`word_summaries`) とブックマークには触れない。
