## Purpose

Persist each novel's last opened file in the SQLite metadata database so the viewer can auto-open that file when the user re-enters the novel folder. Provides CRUD APIs for the one-row-per-novel `reading_progress` table, the auto-save trigger on file selection, the one-shot auto-open trigger on folder entry, and the WARNING-level failure-degradation contract.

## Requirements

### Requirement: Reading progress data persistence
The system SHALL persist reading progress (last opened file per novel) in the existing SQLite database (`novel_metadata.db`) using a new `reading_progress` table. The database version SHALL be upgraded from 5 to 6 to add the `reading_progress` table.

#### Scenario: Database migration creates reading_progress table
- **WHEN** the application starts with database version 5
- **THEN** the database SHALL be upgraded to version 6 by creating a new `reading_progress` table with columns: `novel_id` (TEXT NOT NULL PRIMARY KEY), `file_path` (TEXT NOT NULL), `file_name` (TEXT NOT NULL), `updated_at` (TEXT NOT NULL)
- **AND** existing data in other tables (novels, bookmarks, word_summaries) SHALL be preserved

#### Scenario: Fresh install creates reading_progress table
- **WHEN** the application is installed for the first time
- **THEN** the database SHALL be created at version 6 with the `reading_progress` table already present

### Requirement: Upsert reading progress
The system SHALL provide an upsert operation that records or replaces the single reading progress record for a given novel. Because `novel_id` is the PRIMARY KEY, each novel SHALL have at most one row.

#### Scenario: First-time progress record
- **WHEN** an upsert is performed for novel_id "narou_n1234ab" with file_path "/library/narou_n1234ab/001_chapter1.txt" and no prior row exists
- **THEN** a new row SHALL be inserted with the provided novel_id, file_path, file_name "001_chapter1.txt", and the current timestamp as updated_at

#### Scenario: Replacing existing progress
- **WHEN** an upsert is performed for novel_id "narou_n1234ab" with file_path "/library/narou_n1234ab/005_chapter5.txt" and a prior row already exists
- **THEN** the existing row SHALL be updated to the new file_path, file_name "005_chapter5.txt", and the current timestamp as updated_at
- **AND** no duplicate row SHALL be created

### Requirement: Read reading progress
The system SHALL provide a lookup operation that returns the single reading progress record for a given novel, or null when no record exists.

#### Scenario: Novel has a progress record
- **WHEN** the reading progress is requested for novel_id "narou_n1234ab" which has a row stored
- **THEN** the operation SHALL return that row's file_path and file_name

#### Scenario: Novel has no progress record
- **WHEN** the reading progress is requested for novel_id "narou_unknown" which has no row stored
- **THEN** the operation SHALL return null

### Requirement: Delete reading progress by novel
The system SHALL provide a deletion operation that removes the reading progress row for a given novel id. This operation SHALL be safe to call when no row exists.

#### Scenario: Existing row is deleted
- **WHEN** deletion is requested for novel_id "narou_n1234ab" which has a row stored
- **THEN** the row SHALL be removed from the `reading_progress` table

#### Scenario: Deletion of a non-existent row
- **WHEN** deletion is requested for a novel_id that has no row
- **THEN** the operation SHALL complete without error and SHALL NOT raise

### Requirement: Auto-save on file selection
When the user opens a file inside a novel folder, the system SHALL upsert that file as the novel's reading progress. The save SHALL be triggered whenever `selectedFileProvider` transitions to a non-null value while the current directory is within a novel folder (i.e., `currentNovelIdProvider` resolves to a non-null novel id). Selections made while the current directory is the library root SHALL NOT save progress.

#### Scenario: User selects a file inside a novel folder
- **WHEN** the user is inside the folder for novel_id "narou_n1234ab" and selects "/library/narou_n1234ab/003_chapter3.txt" via tap or external navigation
- **THEN** the `reading_progress` row for "narou_n1234ab" SHALL be upserted to file_path "/library/narou_n1234ab/003_chapter3.txt"

#### Scenario: Selection is cleared
- **WHEN** `selectedFileProvider` transitions from a non-null `FileEntry` to null (e.g., directory change clears the selection)
- **THEN** no upsert SHALL be performed (the existing progress row remains untouched)

#### Scenario: Selection happens at library root
- **WHEN** `currentDirectoryProvider` equals the library root path and `selectedFileProvider` somehow becomes non-null (defensive case)
- **THEN** no upsert SHALL be performed because no novel id can be resolved

### Requirement: One-shot auto-open on novel folder entry
When the user navigates into a novel folder (i.e., `currentDirectoryProvider` transitions to a path inside the library root such that `currentNovelIdProvider` resolves to a non-null novel id), the system SHALL look up that novel's reading progress and, if a record exists and the recorded file is currently present in the directory listing, SHALL set `selectedFileProvider` to that file exactly once. Subsequent rebuilds or unrelated state changes SHALL NOT re-trigger the auto-open.

The auto-open SHALL NOT fire when the current directory is the library root, and SHALL NOT fire when the user navigates away from a novel folder back to the library root.

#### Scenario: Entering a novel folder with stored progress restores the file
- **WHEN** the user navigates from the library root into the folder for novel_id "narou_n1234ab"
- **AND** `reading_progress` contains a row for "narou_n1234ab" pointing to "/library/narou_n1234ab/003_chapter3.txt"
- **AND** "003_chapter3.txt" is present in the directory's text file listing
- **THEN** `selectedFileProvider` SHALL be set to the `FileEntry` for "003_chapter3.txt" exactly once

#### Scenario: Entering a novel folder with no stored progress
- **WHEN** the user navigates into a novel folder that has no `reading_progress` row
- **THEN** `selectedFileProvider` SHALL remain unchanged (typically null) and no automatic selection SHALL occur

#### Scenario: Stored file is no longer present
- **WHEN** the user navigates into the folder for novel_id "narou_n1234ab"
- **AND** `reading_progress` points to "005_chapter5.txt"
- **AND** the directory listing does not contain "005_chapter5.txt" (e.g., the novel was refreshed and renumbered)
- **THEN** no automatic selection SHALL occur and the user SHALL see the normal unselected listing
- **AND** the existing `reading_progress` row SHALL be left in place (it will be replaced once the user opens any file)

#### Scenario: Auto-open does not override an existing selection on the same entry
- **WHEN** the user navigates into a novel folder where `selectedFileProvider` already holds a `FileEntry` that belongs to this novel (e.g., the entry was set by a sibling code path immediately before the directory change)
- **THEN** the auto-open SHALL NOT overwrite the existing selection

#### Scenario: Re-entering the same folder later does not re-fire after user changes selection
- **WHEN** the user enters a novel folder, the auto-open sets file A, the user then taps file B, and then navigates back to the library root and re-enters the same folder
- **THEN** the auto-open SHALL fire again and select the file currently stored in `reading_progress` (which is now B because the auto-save updated it when the user tapped B)

#### Scenario: Library root entry does not auto-open
- **WHEN** the user navigates to the library root path
- **THEN** no auto-open SHALL occur (no novel id can be resolved at the library root)

### Requirement: Repository failure is observable and non-fatal
When the reading progress repository fails (e.g., the database is locked or corrupt), the system SHALL log the failure at WARNING level via `Logger('reading_progress')` and SHALL degrade gracefully: a failed save SHALL be silently dropped, and a failed read SHALL be treated as "no progress record" so the file listing remains usable. The system SHALL NOT swallow the exception silently (i.e., logging is mandatory).

#### Scenario: Save fails
- **WHEN** the upsert operation throws during a file selection
- **THEN** a WARNING-level `LogRecord` SHALL be emitted on `Logger('reading_progress')` containing the exception
- **AND** the user SHALL NOT see a crash or error dialog (the file remains opened)

#### Scenario: Read fails on folder entry
- **WHEN** the lookup operation throws on novel folder entry
- **THEN** a WARNING-level `LogRecord` SHALL be emitted on `Logger('reading_progress')` containing the exception
- **AND** no automatic selection SHALL occur (the user sees the normal unselected listing)
