## ADDED Requirements

### Requirement: Bookmark data persistence
The system SHALL persist bookmark data in the existing SQLite database (`novel_metadata.db`) using a `bookmarks` table. The database version SHALL be upgraded from 2 to 3 to add this table.

#### Scenario: Database migration creates bookmarks table
- **WHEN** the application starts with database version 2
- **THEN** the database SHALL be upgraded to version 3 with a new `bookmarks` table containing columns: `id` (INTEGER PRIMARY KEY AUTOINCREMENT), `novel_id` (TEXT NOT NULL), `file_name` (TEXT NOT NULL), `file_path` (TEXT NOT NULL), `created_at` (TEXT NOT NULL), with a UNIQUE constraint on (`novel_id`, `file_path`)

#### Scenario: Fresh install creates bookmarks table
- **WHEN** the application is installed for the first time
- **THEN** the database SHALL be created at version 3 with the `bookmarks` table included

### Requirement: Add bookmark
The system SHALL allow adding a bookmark for a specific file within a novel. A bookmark SHALL be uniquely identified by the combination of `novel_id` and `file_path`.

#### Scenario: Add a new bookmark
- **WHEN** a bookmark is added with novel_id "n1234" and file_path "/path/to/001_chapter1.txt"
- **THEN** a new record SHALL be inserted into the `bookmarks` table with the provided novel_id, file_name extracted from the path, file_path, and the current timestamp as created_at

#### Scenario: Add a duplicate bookmark
- **WHEN** a bookmark is added with a novel_id and file_path combination that already exists
- **THEN** the operation SHALL be ignored without error (no duplicate record created)

### Requirement: Remove bookmark
The system SHALL allow removing a bookmark by its novel_id and file_path.

#### Scenario: Remove an existing bookmark
- **WHEN** a bookmark with novel_id "n1234" and file_path "/path/to/001_chapter1.txt" is removed
- **THEN** the corresponding record SHALL be deleted from the `bookmarks` table

#### Scenario: Remove a non-existent bookmark
- **WHEN** a bookmark removal is requested for a novel_id and file_path combination that does not exist
- **THEN** the operation SHALL complete without error

### Requirement: List bookmarks for a novel
The system SHALL provide a list of all bookmarks for a given novel, ordered by creation time (newest first).

#### Scenario: Novel has bookmarks
- **WHEN** bookmarks are requested for novel_id "n1234" which has 3 bookmarks
- **THEN** all 3 bookmarks SHALL be returned, ordered by created_at descending

#### Scenario: Novel has no bookmarks
- **WHEN** bookmarks are requested for a novel_id that has no bookmarks
- **THEN** an empty list SHALL be returned

### Requirement: Check bookmark existence
The system SHALL provide a way to check whether a specific file is bookmarked within a novel.

#### Scenario: File is bookmarked
- **WHEN** a check is made for novel_id "n1234" and file_path "/path/to/001_chapter1.txt" which is bookmarked
- **THEN** the result SHALL be true

#### Scenario: File is not bookmarked
- **WHEN** a check is made for novel_id "n1234" and file_path "/path/to/002_chapter2.txt" which is not bookmarked
- **THEN** the result SHALL be false
