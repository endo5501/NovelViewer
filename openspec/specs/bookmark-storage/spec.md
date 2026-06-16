## Purpose

Persist user bookmarks (novel ID, file name, optional line number) in the SQLite metadata database. Provides CRUD APIs for adding, removing, listing, and checking bookmarks, with database migrations to evolve the `bookmarks` table schema over time.
## Requirements
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

### Requirement: Add bookmark
The system SHALL allow adding a bookmark for a specific file and line within a novel. A bookmark SHALL be uniquely identified by the combination of `novel_id`, `file_name`, and `line_number`. The system SHALL NOT store an absolute file path.

#### Scenario: Add a new bookmark with line number
- **WHEN** a bookmark is added with novel_id "n1234", file_name "001_chapter1.txt", and line_number 42
- **THEN** a new record SHALL be inserted into the `bookmarks` table with the provided novel_id, file_name, line_number 42, and the current timestamp as created_at

#### Scenario: Add a bookmark without line number
- **WHEN** a bookmark is added with novel_id "n1234", file_name "001_chapter1.txt", and line_number null
- **THEN** a new record SHALL be inserted with line_number as NULL

#### Scenario: Add a duplicate bookmark (same file and line)
- **WHEN** a bookmark is added with a novel_id, file_name, and line_number combination that already exists
- **THEN** the operation SHALL be ignored without error (no duplicate record created)

#### Scenario: Add bookmarks for different lines in same file
- **WHEN** a bookmark is added with novel_id "n1234", file_name "001_chapter1.txt", line_number 42
- **AND** another bookmark is added with novel_id "n1234", file_name "001_chapter1.txt", line_number 100
- **THEN** both bookmarks SHALL be stored as separate records

### Requirement: Remove bookmark
The system SHALL allow removing a bookmark by its novel_id, file_name, and line_number.

#### Scenario: Remove an existing bookmark with line number
- **WHEN** a bookmark with novel_id "n1234", file_name "001_chapter1.txt", and line_number 42 is removed
- **THEN** the corresponding record SHALL be deleted from the `bookmarks` table

#### Scenario: Remove a non-existent bookmark
- **WHEN** a bookmark removal is requested for a novel_id, file_name, and line_number combination that does not exist
- **THEN** the operation SHALL complete without error

### Requirement: List bookmarks for a novel
The system SHALL provide a list of all bookmarks for a given novel, ordered by creation time (newest first).

#### Scenario: Novel has bookmarks with line numbers
- **WHEN** bookmarks are requested for novel_id "n1234" which has 3 bookmarks (including some with line numbers)
- **THEN** all 3 bookmarks SHALL be returned with their line_number values, ordered by created_at descending

#### Scenario: Novel has no bookmarks
- **WHEN** bookmarks are requested for a novel_id that has no bookmarks
- **THEN** an empty list SHALL be returned

### Requirement: Check bookmark existence
The system SHALL provide a way to check whether a specific file and line combination is bookmarked within a novel, keyed on `novel_id` and `file_name`.

#### Scenario: File and line is bookmarked
- **WHEN** a check is made for novel_id "n1234", file_name "001_chapter1.txt", and line_number 42 which is bookmarked
- **THEN** the result SHALL be true

#### Scenario: File is bookmarked at different line
- **WHEN** a check is made for novel_id "n1234", file_name "001_chapter1.txt", and line_number 50, but only line 42 is bookmarked
- **THEN** the result SHALL be false

#### Scenario: File is not bookmarked
- **WHEN** a check is made for novel_id "n1234" and file_name "002_chapter2.txt" which is not bookmarked
- **THEN** the result SHALL be false

### Requirement: Find bookmarks for a specific file
The system SHALL provide a way to retrieve all bookmarks for a specific file within a novel, keyed on `novel_id` and `file_name`.

#### Scenario: File has multiple bookmarks
- **WHEN** bookmarks are requested for novel_id "n1234" and file_name "001_chapter1.txt" which has bookmarks at lines 10, 42, and 100
- **THEN** all 3 bookmarks SHALL be returned with their line_number values

#### Scenario: File has no bookmarks
- **WHEN** bookmarks are requested for a novel_id and file_name combination that has no bookmarks
- **THEN** an empty list SHALL be returned

### Requirement: Bookmark jump is move/rename-safe
When the user opens (jumps to) a stored bookmark, the system SHALL resolve the target file's absolute path from the novel's current folder location and the bookmark's `file_name`, rather than from any persisted absolute path. As a fail-safe, the system SHALL verify the resolved file exists before navigating and SHALL show the existing "file not found" message when it does not.

#### Scenario: Jump after the novel folder was moved or renamed
- **WHEN** a bookmark was created while the novel lived at one path, the novel folder is later moved or renamed, and the user opens that bookmark while viewing the novel at its new location
- **THEN** the system SHALL resolve the target file under the novel's current folder using the bookmark's `file_name` and navigate to it (selecting the file and, if present, jumping to the stored line number)

#### Scenario: Jump when the target file no longer exists
- **WHEN** the user opens a bookmark whose `file_name` is not present in the novel's current folder
- **THEN** the system SHALL NOT navigate and SHALL show the "file not found" message

