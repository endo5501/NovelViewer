## Context

`novel_metadata.db` のスキーマは本番の `NovelDatabase._onCreate`（`lib/features/novel_metadata_db/data/novel_database.dart:98`）と `_onUpgrade`（同:122）が唯一の正である。しかしテスト側では約15ファイルが `onCreate` コールバック内で `CREATE TABLE` を手書きしており（`bookmark_providers_test` / `bookmark_repository_test` / `reading_progress_*` / `novel_delete_service_test` / `llm_summary_*` / `fact_cache_repository_test` など）、本番DDLと独立に進化し得る。これが F130（スキーマドリフトがテストをすり抜ける）の根。

移行検証は部分的に整備済み。F128（fix-bookmark-progress-relative-paths）で `novel_database_migration_full_chain_test.dart`（v1→v8 フルチェーン）と v6/v7/v8 個別テストが入った。残るギャップは v3→v4 ブックマーク移行（`_migrateBookmarksAddLineNumber`、:241）のデータ保存検証で、これは現状どのテストでも `line_number=NULL` 付与と既存行保存を明示的にassertしていない（F129残）。検証専用の `runMigrationForTesting`（:543）は v4→v5 のみを対象とし、かつ `_onUpgrade` のステップ順序を迂回するため、各バージョンブロックの相互作用は本番昇格パスでしか検証できない。

手本は既にリポジトリ内にある: `novel_database_migration_v6_test.dart` は `NovelDatabase` 経由でDBを開く正しいパターンを示している。

## Goals / Non-Goals

**Goals:**

- 本番スキーマ定義（`_onCreate`）を単一の正としてテストへ供給する共有シームを確立し、手書きDDLフィクスチャを排除する（F130）。
- v3→v4 移行のデータ保存を、本番 `NovelDatabase` 昇格パス経由のテストで固定する（F129残）。
- 既存の全テストの振る舞いを保ったまま（緑のまま）フィクスチャ構築方法のみを移行する。

**Non-Goals:**

- 本番のスキーマ・マイグレーションロジックの変更（テスト基盤とカバレッジのみ）。
- 死にコード削除（F164/F146/F133）。これは別changeで扱う。
- per-folder DB（`episode_cache.db` / `tts_audio.db` / `tts_dictionary.db`）のテストフィクスチャ統一。本changeは `novel_metadata.db` に限定する（スコープ膨張回避。必要なら後続change）。
- `runMigrationForTesting`（v4→v5専用ヘルパー）の撤去。本番昇格パス経由テストで補完するが、既存ヘルパーは温存する。

## Decisions

### 決定1: 共有スキーマシームの形 — `NovelDatabase` 経由構築を第一選択、補助的に `@visibleForTesting` スキーマヘルパー

テストフィクスチャは原則 `NovelDatabase(dbDirPath:)` + `setDatabase`/`seedResource` シーム（:531）で構築し、本番 `_onCreate` を必ず通す。リポジトリ単体テストのように「最新スキーマの空DB」が欲しいだけのケースはこれで十分。

ただし一部テストは「特定バージョンのスキーマでシード→移行を観察」を必要とする。その用途には本番の各 `_create*Table` 静的メソッド（既に `static` 化されている、例 `_createBookmarksTable` :191）を `@visibleForTesting` で露出する共有ヘルパーを設け、テストが本番定義を直接呼べるようにする。

- **代替案A（不採用）**: テスト側DDLをそのまま残し「正しさはレビューで担保」。→ F130 の指摘そのもので、ドリフトを構造的に防げない。
- **代替案B（不採用）**: 全テストを `NovelDatabase` フル構築に強制。→ 特定バージョンのシードができず移行テストが書けない。バージョン固定の `_create*Table` 露出が必要。

### 決定2: v3→v4 移行テストは本番昇格パス経由（`runMigrationForTesting` を使わない）／v8観測

version=3 の歴史的スキーマ（`line_number` なしの `bookmarks` + v2形 `word_summaries` + `novels`）でシードしたDBを `NovelDatabase` の `database`（version=最新=8）で開き、`_onUpgrade` を実際に走らせて結果を検証する。

**実装時の判明事項（重要）**: `_onUpgrade` の各ステップは `oldVersion < N` のみで分岐し `newVersion` を見ない。そのため「version=4 で開いて v3→v4 単独分離」は不可能で、v3 を開くと常に v3→v8 のフルチェーンが走る（試作した `openAtVersionForTesting` シームは分離できず撤回）。よって v3→v4 の寄与は **v8 終端で観測**する: pre-v4 行が `line_number=NULL` を付与されたまま生き残ること（行消失せず、NULL 付与の署名が残ること）を検証する。`file_path` 保持は v7→v8 で列が落ちるため終端では観測不能。本番マイグレーションの分岐ロジック変更は Non-Goal のため、この観測点で妥協する。

- **代替案（不採用）**: `runMigrationForTesting` を v3→v4 用に拡張。→ ヘルパー自体が `_onUpgrade` の順序を迂回する設計（F129指摘）なので、迂回路を増やすことになり本末転倒。
- **代替案（不採用）**: `_onUpgrade` に `newVersion` ガードを足して目標バージョンで停止可能にする。→ 本番マイグレーション分岐の挙動変更でリスクが高く、design の Non-Goal に反する。

### 決定3: TDD順序 — まず移行テストを赤で固定、次にフィクスチャ移行

CLAUDE.md の MUST に従い、先に v3→v4 データ保存テスト（新規）を書いて現挙動を固定する。フィクスチャ移行は「振る舞い不変リファクタ」なので、各ファイル移行後に既存テストが緑のままであることを以て回帰なしを担保する。

## Risks / Trade-offs

- **[共有ヘルパー露出で本番APIに `@visibleForTesting` シームが増える]** → 既存の `setDatabase`/`runMigrationForTesting` と同じ確立済みパターンに乗せ、新規シームは最小限（バージョン別 `_create*Table` の露出のみ）に留める。
- **[約15ファイルの一括移行でレビュー差分が大きい]** → 機能単位（bookmark / reading_progress / llm_summary / novel_delete）でコミットを分割し、各コミットで `fvm flutter test` 緑を確認。スコープを `novel_metadata.db` に限定して総量を抑える。
- **[フィクスチャを本番スキーマに寄せた結果、テストが暗黙に依存していた「緩いスキーマ」が露呈してテストが赤化する]** → それはまさに検出したかったドリフト。赤化した場合はテスト側の誤った前提を本番スキーマ準拠に修正する（本changeの目的に合致）。
- **[per-folder DB を対象外にしたことで F130 が完全には閉じない]** → proposal/specで `novel_metadata.db` 限定と明記。残りは後続changeのNon-Goalとして記録。

## Migration Plan

1. v3→v4 ブックマーク移行のデータ保存テストを新規追加（赤で固定 → 既に本番実装があるため即緑になる場合は「現挙動の固定」として扱う）。
2. バージョン別スキーマ供給の共有 `@visibleForTesting` ヘルパーを整備（本番 `_create*Table` の露出 or 専用テストユーティリティ）。
3. 手書きDDLフィクスチャを機能単位で共有スキーマ経由へ移行。各単位ごとに `fvm flutter test` で緑を確認。
4. `fvm flutter analyze` / `fvm flutter test` 全緑、code-review/codex レビューを経てアーカイブ。

ロールバック: 本changeはテスト基盤のみ変更のため、問題発生時は該当コミットのrevertで本番影響なく戻せる。

## Open Questions

- ~~共有スキーマヘルパーの置き場~~ → 決着: 両方を採用。本番側に `@visibleForTesting static NovelDatabase.createCurrentSchema(db)`（スキーマ定義の単一の正）を露出し、`test/helpers/novel_metadata_db_fixture.dart`（`openInMemoryNovelMetadataDb` / `seedNovelDatabaseFixture`）がそれに委譲する薄いラッパとして同居。ドリフトは `schema_fidelity_test`（tables + indexes 比較）で固定。
