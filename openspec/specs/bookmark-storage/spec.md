## Purpose

Persist user bookmarks (novel ID, file path, optional line number) in the SQLite metadata database. Provides CRUD APIs for adding, removing, listing, and checking bookmarks, with database migrations to evolve the `bookmarks` table schema over time.

## Requirements

### Requirement: Bookmark data persistence
The system SHALL persist bookmark data in the existing SQLite database (`novel_metadata.db`) using a `bookmarks` table. The database version SHALL be upgraded from 3 to 4 to add the `line_number` column and update the UNIQUE constraint.

#### Scenario: Database migration creates bookmarks table
- **WHEN** the application starts with database version 2
- **THEN** the database SHALL be upgraded to version 3 with a new `bookmarks` table containing columns: `id` (INTEGER PRIMARY KEY AUTOINCREMENT), `novel_id` (TEXT NOT NULL), `file_name` (TEXT NOT NULL), `file_path` (TEXT NOT NULL), `created_at` (TEXT NOT NULL), with a UNIQUE constraint on (`novel_id`, `file_path`)

#### Scenario: Database migration adds line_number column
- **WHEN** the application starts with database version 3
- **THEN** the database SHALL be upgraded to version 4 by recreating the `bookmarks` table with columns: `id` (INTEGER PRIMARY KEY AUTOINCREMENT), `novel_id` (TEXT NOT NULL), `file_name` (TEXT NOT NULL), `file_path` (TEXT NOT NULL), `line_number` (INTEGER), `created_at` (TEXT NOT NULL), with a UNIQUE constraint on (`novel_id`, `file_path`, `line_number`)
- **AND** existing bookmark data SHALL be preserved with `line_number` set to NULL

#### Scenario: Fresh install creates bookmarks table
- **WHEN** the application is installed for the first time
- **THEN** the database SHALL be created at version 4 with the `bookmarks` table including the `line_number` column and UNIQUE constraint on (`novel_id`, `file_path`, `line_number`)

### Requirement: Add bookmark
The system SHALL allow adding a bookmark for a specific file and line within a novel. A bookmark SHALL be uniquely identified by the combination of `novel_id`, `file_path`, and `line_number`.

#### Scenario: Add a new bookmark with line number
- **WHEN** a bookmark is added with novel_id "n1234", file_path "/path/to/001_chapter1.txt", and line_number 42
- **THEN** a new record SHALL be inserted into the `bookmarks` table with the provided novel_id, file_name extracted from the path, file_path, line_number 42, and the current timestamp as created_at

#### Scenario: Add a bookmark without line number
- **WHEN** a bookmark is added with novel_id "n1234", file_path "/path/to/001_chapter1.txt", and line_number null
- **THEN** a new record SHALL be inserted with line_number as NULL

#### Scenario: Add a duplicate bookmark (same file and line)
- **WHEN** a bookmark is added with a novel_id, file_path, and line_number combination that already exists
- **THEN** the operation SHALL be ignored without error (no duplicate record created)

#### Scenario: Add bookmarks for different lines in same file
- **WHEN** a bookmark is added with novel_id "n1234", file_path "/path/to/001_chapter1.txt", line_number 42
- **AND** another bookmark is added with novel_id "n1234", file_path "/path/to/001_chapter1.txt", line_number 100
- **THEN** both bookmarks SHALL be stored as separate records

### Requirement: Remove bookmark
The system SHALL allow removing a bookmark by its novel_id, file_path, and line_number.

#### Scenario: Remove an existing bookmark with line number
- **WHEN** a bookmark with novel_id "n1234", file_path "/path/to/001_chapter1.txt", and line_number 42 is removed
- **THEN** the corresponding record SHALL be deleted from the `bookmarks` table

#### Scenario: Remove a non-existent bookmark
- **WHEN** a bookmark removal is requested for a novel_id, file_path, and line_number combination that does not exist
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
The system SHALL provide a way to check whether a specific file and line combination is bookmarked within a novel.

#### Scenario: File and line is bookmarked
- **WHEN** a check is made for novel_id "n1234", file_path "/path/to/001_chapter1.txt", and line_number 42 which is bookmarked
- **THEN** the result SHALL be true

#### Scenario: File is bookmarked at different line
- **WHEN** a check is made for novel_id "n1234", file_path "/path/to/001_chapter1.txt", and line_number 50, but only line 42 is bookmarked
- **THEN** the result SHALL be false

#### Scenario: File is not bookmarked
- **WHEN** a check is made for novel_id "n1234" and file_path "/path/to/002_chapter2.txt" which is not bookmarked
- **THEN** the result SHALL be false

### Requirement: Find bookmarks for a specific file
The system SHALL provide a way to retrieve all bookmarks for a specific file within a novel.

#### Scenario: File has multiple bookmarks
- **WHEN** bookmarks are requested for novel_id "n1234" and file_path "/path/to/001_chapter1.txt" which has bookmarks at lines 10, 42, and 100
- **THEN** all 3 bookmarks SHALL be returned with their line_number values

#### Scenario: File has no bookmarks
- **WHEN** bookmarks are requested for a novel_id and file_path combination that has no bookmarks
- **THEN** an empty list SHALL be returned
