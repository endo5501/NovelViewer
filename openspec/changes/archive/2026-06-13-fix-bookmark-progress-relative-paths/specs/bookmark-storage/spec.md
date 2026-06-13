## MODIFIED Requirements

### Requirement: Bookmark data persistence
The system SHALL persist bookmark data in the existing SQLite database (`novel_metadata.db`) using a `bookmarks` table. The bookmark identity SHALL be the move/rename-safe combination of `novel_id` and `file_name` (plus optional `line_number`); the table SHALL NOT persist the absolute file path. The database version SHALL be upgraded to 8, which recreates the `bookmarks` table to drop the `file_path` column and change the UNIQUE constraint from (`novel_id`, `file_path`, `line_number`) to (`novel_id`, `file_name`, `line_number`).

#### Scenario: Database migration creates bookmarks table (legacy v2 → v3)
- **WHEN** the application starts with database version 2
- **THEN** the database SHALL be upgraded to version 3 with a `bookmarks` table containing columns: `id` (INTEGER PRIMARY KEY AUTOINCREMENT), `novel_id` (TEXT NOT NULL), `file_name` (TEXT NOT NULL), `file_path` (TEXT NOT NULL), `created_at` (TEXT NOT NULL), with a UNIQUE constraint on (`novel_id`, `file_path`)

#### Scenario: Database migration adds line_number column (legacy v3 → v4)
- **WHEN** the application starts with database version 3
- **THEN** the database SHALL be upgraded to version 4 by recreating the `bookmarks` table with columns including `line_number` (INTEGER) and `file_path` (TEXT NOT NULL), with a UNIQUE constraint on (`novel_id`, `file_path`, `line_number`)
- **AND** existing bookmark data SHALL be preserved with `line_number` set to NULL

#### Scenario: Database migration drops file_path and re-keys on file_name (v7 → v8)
- **WHEN** the application starts with a database at version 7 whose `bookmarks` table still has a `file_path` column and a UNIQUE constraint on (`novel_id`, `file_path`, `line_number`)
- **THEN** the database SHALL be upgraded to version 8 by recreating the `bookmarks` table with columns: `id` (INTEGER PRIMARY KEY AUTOINCREMENT), `novel_id` (TEXT NOT NULL), `file_name` (TEXT NOT NULL), `line_number` (INTEGER), `created_at` (TEXT NOT NULL), with a UNIQUE constraint on (`novel_id`, `file_name`, `line_number`)
- **AND** the `file_path` column SHALL be removed
- **AND** existing rows SHALL be preserved, carrying over `id`, `novel_id`, `file_name`, `line_number`, and `created_at`

#### Scenario: Migration deduplicates rows that collide on the new key
- **WHEN** the v7 `bookmarks` table contains two rows with the same (`novel_id`, `file_name`, `line_number`) but different `file_path` values
- **THEN** the v8 migration SHALL keep exactly one row (the one with the earliest `created_at`) and drop the other without raising

#### Scenario: Fresh install creates bookmarks table at v8
- **WHEN** the application is installed for the first time
- **THEN** the database SHALL be created at version 8 with the `bookmarks` table containing `id`, `novel_id`, `file_name`, `line_number`, `created_at` (no `file_path` column) and a UNIQUE constraint on (`novel_id`, `file_name`, `line_number`)

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

## ADDED Requirements

### Requirement: Bookmark jump is move/rename-safe
When the user opens (jumps to) a stored bookmark, the system SHALL resolve the target file's absolute path from the novel's current folder location and the bookmark's `file_name`, rather than from any persisted absolute path. As a fail-safe, the system SHALL verify the resolved file exists before navigating and SHALL show the existing "file not found" message when it does not.

#### Scenario: Jump after the novel folder was moved or renamed
- **WHEN** a bookmark was created while the novel lived at one path, the novel folder is later moved or renamed, and the user opens that bookmark while viewing the novel at its new location
- **THEN** the system SHALL resolve the target file under the novel's current folder using the bookmark's `file_name` and navigate to it (selecting the file and, if present, jumping to the stored line number)

#### Scenario: Jump when the target file no longer exists
- **WHEN** the user opens a bookmark whose `file_name` is not present in the novel's current folder
- **THEN** the system SHALL NOT navigate and SHALL show the "file not found" message
