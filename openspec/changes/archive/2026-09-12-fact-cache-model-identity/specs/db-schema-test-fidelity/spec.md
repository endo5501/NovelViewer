## MODIFIED Requirements

### Requirement: バージョン移行のデータ保存をテストで固定する

`novel_metadata.db` および `novel_data.db` の各バージョン移行は、旧バージョンでシードしたDBを本番の昇格パス（それぞれ `NovelDatabase._onUpgrade` / `NovelDataDatabase` の `onUpgrade`）経由で開いたうえで、データ保存とスキーマ変換を検証しなければならない（SHALL）。`_onUpgrade` のステップ順序を迂回する検証専用ヘルパーのみに依存してはならない（MUST NOT）。

旧バージョンのDBをシードする目的に限り、手書きの歴史的 DDL を用いてよい。現行スキーマを手書き DDL で代用することの禁止（前要件）とは両立する。旧バージョンの定義は本番コードにもう存在しないため、それを再現する手段は他にない。

#### Scenario: v3→v4 ブックマーク移行のデータ保存

- **WHEN** 歴史的 v3 スキーマ（`line_number` を持たない `bookmarks`）に行をシードし、`NovelDatabase` を最新バージョンで開いて本番昇格パスで昇格させる
- **THEN** v3→v4 ステップで導入された `line_number` 列が存在し、pre-v4 の各行は novel_id / file_name / created_at を保持したまま生き残り、その `line_number` は `NULL` になる（`_onUpgrade` は `oldVersion` のみで分岐するため最終状態は v8 で観測される）

#### Scenario: 本番昇格パス経由でのフルチェーン検証

- **WHEN** 旧バージョン（v1 を含む各歴史版）でシードしたDBを `NovelDatabase` の本番昇格パスで開く
- **THEN** 各 `_onUpgrade` ステップが宣言順に適用され、最終スキーマと移行済みデータが期待どおりになる

#### Scenario: `novel_data.db` の移行も本番昇格パスで検証される

- **WHEN** `model_id` を持たない歴史的スキーマでシードした `novel_data.db` を、本番の `NovelDataDatabase` から最新バージョンで開く
- **THEN** 本番の `onUpgrade` が適用され、`fact_cache` が現行スキーマになり、`word_summaries` と `bookmarks` の行が保持される
