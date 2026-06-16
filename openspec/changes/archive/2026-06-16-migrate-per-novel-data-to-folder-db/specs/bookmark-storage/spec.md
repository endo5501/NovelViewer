## MODIFIED Requirements

### Requirement: Bookmark data persistence
The system SHALL persist bookmark data **in the per-folder `novel_data.db` of the bookmarked novel** using a `bookmarks` table. The table SHALL NOT carry a `novel_id` column; the novel identity is conveyed by which folder's `novel_data.db` the row lives in. The bookmark identity within a novel SHALL be the move/rename-safe combination of `file_name` plus optional `line_number`; the table SHALL NOT persist the absolute file path. The `BookmarkRepository` SHALL be constructed with a folder-scoped `novel_data.db` handle and its operations SHALL NOT take a `novel_id` argument.

The legacy global `bookmarks` table in `novel_metadata.db` SHALL be dropped at schema version 9 after its rows are migrated into each novel's `novel_data.db`.

#### Scenario: Fresh install creates bookmarks table in novel_data.db
- **WHEN** the user adds the first bookmark for a novel
- **THEN** that novel's `novel_data.db` SHALL contain a `bookmarks` table with columns `id` (INTEGER PRIMARY KEY AUTOINCREMENT), `file_name` (TEXT NOT NULL), `line_number` (INTEGER), `created_at` (TEXT NOT NULL), with a UNIQUE constraint on (`file_name`, `line_number`), and no `novel_id` or `file_path` column

#### Scenario: Bookmark identity within a novel
- **WHEN** a bookmark is added for `file_name="010_ch.txt"` at `line_number=42`
- **THEN** the row is uniquely identified within the novel by (`file_name`, `line_number`), without reference to the absolute path or a novel id

#### Scenario: Existing global bookmarks migrate to novel_data.db
- **WHEN** the application starts with a `novel_metadata.db` whose `bookmarks` table contains rows keyed by `novel_id`
- **THEN** each row SHALL be copied (upsert) into the `bookmarks` table of the `novel_data.db` for the folder whose name equals `novel_id`, dropping the `novel_id` column
- **AND** after all extant folders are migrated, the global `bookmarks` table SHALL be dropped at version 9
