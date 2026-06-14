# db-schema-test-fidelity Specification

## Purpose
TBD - created by archiving change harden-db-test-schema-fidelity. Update Purpose after archive.
## Requirements
### Requirement: テストは本番スキーマ定義経由でDBを構築する

`novel_metadata.db` を対象とするテストは、テーブルスキーマを手書きの `CREATE TABLE` DDL で定義してはならない（MUST NOT）。代わりに、本番の `NovelDatabase._onCreate`（またはそれを単一の正として露出する共有スキーマヘルパー）を経由してテスト用DBを構築しなければならない（SHALL）。これにより、本番スキーマの変更がテスト側に追従しないことに起因するスキーマドリフトを排除する。

#### Scenario: 本番スキーマ変更がテストへ伝播する

- **WHEN** `NovelDatabase._onCreate` のテーブル定義（列追加・制約変更など）が変更される
- **THEN** 共有スキーマ経由で構築される全テストフィクスチャが同じスキーマを参照し、本番とテストのスキーマが食い違ったまま緑になることがない

#### Scenario: 手書きDDLフィクスチャの不在

- **WHEN** リポジトリ内のテストコードを走査する
- **THEN** `novel_metadata.db` の各テーブル（novels / word_summaries / bookmarks / reading_progress / fact_cache）について、本番スキーマ定義から独立した手書き `CREATE TABLE` フィクスチャが存在しない

### Requirement: バージョン移行のデータ保存をテストで固定する

`novel_metadata.db` の各バージョン移行は、旧バージョンでシードしたDBを本番の `NovelDatabase` 昇格パス（`_onUpgrade`）経由で開いたうえで、データ保存とスキーマ変換を検証しなければならない（SHALL）。`_onUpgrade` のステップ順序を迂回する検証専用ヘルパーのみに依存してはならない（MUST NOT）。

#### Scenario: v3→v4 ブックマーク移行のデータ保存

- **WHEN** 歴史的 v3 スキーマ（`line_number` を持たない `bookmarks`）に行をシードし、`NovelDatabase` を最新バージョンで開いて本番昇格パスで昇格させる
- **THEN** v3→v4 ステップで導入された `line_number` 列が存在し、pre-v4 の各行は novel_id / file_name / created_at を保持したまま生き残り、その `line_number` は `NULL` になる（`_onUpgrade` は `oldVersion` のみで分岐するため最終状態は v8 で観測される）

#### Scenario: 本番昇格パス経由でのフルチェーン検証

- **WHEN** 旧バージョン（v1 を含む各歴史版）でシードしたDBを `NovelDatabase` の本番昇格パスで開く
- **THEN** 各 `_onUpgrade` ステップが宣言順に適用され、最終スキーマと移行済みデータが期待どおりになる
