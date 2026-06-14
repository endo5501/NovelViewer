## Why

`novel_metadata.db` のスキーマ定義は本番の `NovelDatabase._onCreate` / `_onUpgrade` が唯一の正だが、テスト側（約15ファイル）が `CREATE TABLE` を手書きコピーしている（F130）。本番DDLが変わってもテスト側は追従しないため、**スキーマドリフトがテストをすり抜けて本番でだけ壊れる**構造になっている。あわせて v3→v4 ブックマーク移行（RENAME→再作成→コピー→DROP）のデータ保存はテストで固定されておらず（F129残）、移行ロジックのデグレが検出できない。Tech Debt Audit のテーマ7「テストの分布問題」の中核であり、TDD駆動リポジトリにとって思想と実態の最大ギャップ。

## What Changes

- テストDBスキーマ構築を**本番スキーマ定義に一本化**する。手書き `CREATE TABLE` フィクスチャを、本番の `_onCreate` を経由する共有ヘルパー（または `NovelDatabase` 経由のシード）へ移行し、スキーマドリフトをコンパイル/テスト時に検出可能にする（F130）。
- v3→v4 ブックマーク移行（`_migrateBookmarksAddLineNumber`）の**データ保存をテストで固定**する。version=3 でシードしたDBを `NovelDatabase` の本番昇格パスで開き、`line_number=NULL` 付与と既存行（id/novel_id/file_path/created_at）の保存を検証する（F129残）。`runMigrationForTesting` が `_onUpgrade` のステップ順序を迂回する問題を、本番昇格パス経由のテストで補完する。
- 本番スキーマの「単一の正」をテストへ供給する仕組み（共有スキーマヘルパー or `NovelDatabase(dbDirPath:)`+`setDatabase`）を整備し、今後の新規テストが手書きDDLに戻らない規律を確立する。
- 既存の挙動・本番コードのスキーマは**変更しない**（テスト基盤とテストカバレッジのみの変更）。

## Capabilities

### New Capabilities
- `db-schema-test-fidelity`: テストが `novel_metadata.db` のスキーマ・マイグレーションを本番定義経由で検証することを保証する規律。手書きDDLによるスキーマドリフトの防止と、各バージョン移行のデータ保存検証を要件として定める。

### Modified Capabilities
<!-- 本番のスキーマ/マイグレーション挙動は変更しないため、novel-metadata-db spec の要件変更はなし -->

## Impact

- **テストコード**: 手書き `CREATE TABLE` / `onCreate` を持つ約15ファイル（`bookmark_*`, `reading_progress_*`, `novel_delete_service_test`, `llm_summary_*`, `fact_cache_repository_test` ほか）を共有スキーマ経由へ移行。
- **テストヘルパー**: 本番 `_onCreate` を露出する共有スキーマヘルパー（`@visibleForTesting` シーム）を新設、または `NovelDatabase(dbDirPath:)` ベースのフィクスチャ構築へ統一。手本は既存の `novel_database_migration_v6_test.dart`。
- **新規テスト**: v3→v4 移行のデータ保存テストを追加（フルチェーン土台 `novel_database_migration_full_chain_test.dart` は F128 で既設のため、それに相乗り）。
- **本番コード `lib/`**: 原則変更なし。テストアクセス用の `@visibleForTesting` シームを最小限追加する可能性のみ。
- **依存・外部システム**: なし。
