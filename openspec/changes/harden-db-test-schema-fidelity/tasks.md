## 1. v3→v4 移行のデータ保存テスト（TDDファースト）

- [x] 1.1 version=3 のスキーマ（`line_number` なしの旧 `bookmarks`）でDBをシードし、`NovelDatabase` を最新バージョンで開いて昇格させるテストを新規追加
- [x] 1.2 pre-v4 `bookmarks` 行が novel_id / file_name / created_at を保持し、`line_number` が `NULL` になることをassert（v8観測点。`_onUpgrade` は `oldVersion` のみ分岐のため単独分離不可と判明）
- [x] 1.3 テストが `runMigrationForTesting` を使わず本番 `_onUpgrade` 経由であることを確認（ステップ順序を迂回しない）
- [x] 1.4 `fvm flutter test` で当該テストが通る（現挙動の固定）ことを確認

## 2. 共有スキーマシームの整備

- [x] 2.1 本番 `_onCreate` を静的 `@visibleForTesting` `NovelDatabase.createCurrentSchema` へ抽出し、`test/helpers/novel_metadata_db_fixture.dart`（`openInMemoryNovelMetadataDb` / `seedNovelDatabaseFixture`）を整備。スキーマ一致を `schema_fidelity_test.dart` で固定
- [x] 2.2 歴史版スキーマ（v3 旧 bookmarks 等）は移行テスト内の seed ヘルパーで供給（本番非保持のため手書き正当。v8テストと同パターン）
- [x] 2.3 手本（`novel_database_migration_v6_test.dart` の `NovelDatabase` 経由構築）と整合する共有ヘルパー利用パターンを確立

## 3. 手書きDDLフィクスチャの移行（機能単位・振る舞い不変）

- [x] 3.1 bookmark 系（`bookmark_providers_test` / `bookmark_repository_test`）を共有スキーマ経由へ移行し `fvm flutter test` 緑を確認（60件パス）
- [x] 3.2 reading_progress 系（`reading_progress_repository_test` / `reading_progress_providers_test` / `reading_progress_wiring_test`）を移行し緑を確認（34件パス）
- [x] 3.3 llm_summary 系（`fact_cache_repository_test` / `llm_summary_repository_test` / `llm_summary_service_test` / `llm_summary_service_cache_test` / `llm_summary_history_provider_test` / `hover_popup_cache_provider_test`）を移行し緑を確認（273件パス）
- [x] 3.4 novel_delete 系（`novel_delete_service_test`）＋ `novel_repository_test` を移行し緑を確認
- [x] 3.5 走査の結果、現行スキーマの手書き `CREATE TABLE` フィクスチャは一掃。残る5件は移行テスト（v1/v3/v5/v6/v7 等の歴史版シード）のみで、本番非保持のため手書き正当
- [x] 3.6 機能的ドリフトは表面化せず（本番v8スキーマ経由で全テスト緑）。`bookmark_providers_test` の旧 `summary_type` word_summaries や version不一致といった構造的ドリフトは、本番スキーマ経由化で根絶（assertion修正は不要だった）

## 4. 最終確認

- [x] 4.1 code-reviewスキルを使用してコードレビューを実施（本番シーム=忠実抽出でバグゼロ確認。ドリフトガードのindex未検査を指摘採用し`type IN ('table','index')`へ強化）
- [x] 4.2 codexスキルを使用して現在開発中のコードレビューを実施（具体的指摘なし。シームの挙動保存・共有スキーマ移行・v4テストの有効性を確認）
- [x] 4.3 `fvm flutter analyze`でリントを実行（No issues found）
- [x] 4.4 `fvm flutter test`でテストを実行（2141件パス / 1スキップ）
