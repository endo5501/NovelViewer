# Spec Delta

## MODIFIED Requirements

### Requirement: Novel metadata storage
The system SHALL store novel metadata in a `novels` table with the following fields: auto-increment ID, site type, novel ID, title, URL, folder name, episode count, downloaded timestamp, updated timestamp, the total episode count last observed by an update check, and the timestamp of that check. The last two fields SHALL be nullable; NULL means the novel has never been checked successfully. The system SHALL provide a method to delete a novel record by folder name. Deleting a novel record SHALL NOT cascade to `word_summaries`, `fact_cache`, or `bookmarks`, because those tables no longer live in `novel_metadata.db` (they are removed with the novel's folder via its `novel_data.db`).

The system SHALL provide a method that records an update-check result (observed total episode count and check timestamp) for a novel identified by folder name, without changing any other field of that record. Re-downloading a novel SHALL NOT clear a recorded update-check result.

#### Scenario: Novel metadata is registered after download
- **WHEN** a novel download completes successfully
- **THEN** a record is inserted into the novels table with the site type, novel ID, title, source URL, ID-based folder name, episode count, and current timestamp
- **AND** the observed total episode count and the check timestamp are NULL

#### Scenario: Duplicate novel download updates existing record
- **WHEN** a novel with the same site type and novel ID is downloaded again
- **THEN** the existing record is updated with the new title, episode count, and updated timestamp instead of creating a duplicate
- **AND** the recorded update-check result is left unchanged

#### Scenario: Delete novel by folder name
- **WHEN** NovelRepository.deleteByFolderName(folderName) is called
- **THEN** the novel record matching the given folder name is deleted from the novels table
- **AND** no `word_summaries` / `fact_cache` / `bookmarks` rows are touched in `novel_metadata.db` (those tables no longer exist there)

#### Scenario: Record an update-check result
- **WHEN** an update-check result with total episode count 125 is recorded for an existing folder name
- **THEN** that record's observed total episode count is 125 and its check timestamp is the time of the check
- **AND** its title, URL, episode count, downloaded timestamp, and updated timestamp are unchanged

## ADDED Requirements

### Requirement: スキーマバージョン 13 で更新チェックの列を追加する

システムは、`novel_metadata.db` をスキーマバージョン 13 に上げなければならない（SHALL）。v12→v13 の昇格では、`novels` テーブルに、更新チェックで取得した総話数とチェック日時の2つの列を追加しなければならない（SHALL）。どちらも NULL を許し、既存の行では NULL でなければならない（SHALL）。

既存の行の他の列の値と、他のテーブルとその行には、一切手を触れてはならない（SHALL NOT）。新規作成と昇格は、同じ列定義を経由しなければならない（SHALL）。昇格後のスキーマは、新規作成した v13 のスキーマと一致しなければならない（SHALL）。

#### Scenario: v12 の DB が昇格される
- **WHEN** `user_version=12` の `novel_metadata.db` でアプリを起動する
- **THEN** `novels` テーブルに2つの列が追加され、`user_version` は 13 になる
- **AND** 既存の小説の行はすべて保持され、追加した2つの列は NULL である
- **AND** `reading_progress`、参照元関係のテーブル、同期用のテーブルの行はすべて保持される

#### Scenario: 昇格後のスキーマが新規作成と一致する
- **WHEN** v12 から昇格した DB と、新規作成した v13 の DB の `novels` テーブルの定義を比較する
- **THEN** 列の名前・型・NULL 許容が一致する
