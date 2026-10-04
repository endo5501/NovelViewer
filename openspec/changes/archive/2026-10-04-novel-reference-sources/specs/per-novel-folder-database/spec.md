# Spec Delta

## ADDED Requirements

### Requirement: v2→v3 で `word_summaries` に参照元の一覧の列を追加する

システムは、`novel_data.db` をスキーマバージョン 3 に上げなければならない（SHALL）。v3 の `word_summaries` は、スナップショットが解析に使った参照元の一覧（`llm-summary-cache`）を保持する列を持つ。

v2→v3 の昇格では、`word_summaries` のすべての既存の行を、`word`・`covered_up_to_episode`・`summary`・`source_file`・`created_at`・`updated_at` を変えずに保持しなければならない（SHALL）。既存の行の参照元の一覧は、空として扱われなければならない（SHALL）。`fact_cache` と `bookmarks` には一切手を触れてはならない（SHALL NOT）。

昇格後の `word_summaries` のテーブル定義と一意インデックスは、新規作成した v3 の DB と一致しなければならない（SHALL）。新規作成・昇格・テストフィクスチャ・v8→v9 の移送は、いずれも同じ現行スキーマの定義を経由し、`user_version` に 3 を刻まなければならない（SHALL）。

#### Scenario: v2 のDBが昇格され、要約が保持される
- **WHEN** `word_summaries` に行がある `user_version=2` の `novel_data.db` を開く
- **THEN** `user_version` は 3 になり、すべての行が元の値のまま保持される
- **AND** それらの行の参照元の一覧は空として読まれる

#### Scenario: 昇格は他のテーブルに触れない
- **WHEN** `fact_cache` と `bookmarks` に行がある v2 の DB を昇格させる
- **THEN** 両テーブルの行はすべて保持される

#### Scenario: 昇格後のスキーマが新規作成と一致する
- **WHEN** v2 から昇格した DB と、新規作成した v3 の DB の `word_summaries` を比較する
- **THEN** テーブル定義と一意インデックスが一致する
