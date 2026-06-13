## MODIFIED Requirements

### Requirement: Reading progress data persistence
The system SHALL persist reading progress (last opened file per novel) in the existing SQLite database (`novel_metadata.db`) using a `reading_progress` table. The stored progress SHALL identify the file by `file_name` only and SHALL NOT persist an absolute file path. The database version SHALL be upgraded to 8, which recreates the `reading_progress` table to drop the `file_path` column.

#### Scenario: Database migration creates reading_progress table (legacy v5 → v6)
- **WHEN** the application starts with database version 5
- **THEN** the database SHALL be upgraded to version 6 by creating a `reading_progress` table with columns: `novel_id` (TEXT NOT NULL PRIMARY KEY), `file_path` (TEXT NOT NULL), `file_name` (TEXT NOT NULL), `updated_at` (TEXT NOT NULL)
- **AND** existing data in other tables (novels, bookmarks, word_summaries) SHALL be preserved

#### Scenario: Database migration drops file_path (v7 → v8)
- **WHEN** the application starts with a database at version 7 whose `reading_progress` table has a `file_path` column
- **THEN** the database SHALL be upgraded to version 8 by recreating the `reading_progress` table with columns: `novel_id` (TEXT NOT NULL PRIMARY KEY), `file_name` (TEXT NOT NULL), `updated_at` (TEXT NOT NULL)
- **AND** the `file_path` column SHALL be removed
- **AND** existing rows SHALL be preserved, carrying over `novel_id`, `file_name`, and `updated_at`

#### Scenario: Fresh install creates reading_progress table at v8
- **WHEN** the application is installed for the first time
- **THEN** the database SHALL be created at version 8 with the `reading_progress` table present and containing only `novel_id`, `file_name`, `updated_at` (no `file_path` column)

### Requirement: Upsert reading progress
The system SHALL provide an upsert operation that records or replaces the single reading progress record for a given novel. Because `novel_id` is the PRIMARY KEY, each novel SHALL have at most one row. The record SHALL store `file_name` only (no absolute path).

#### Scenario: First-time progress record
- **WHEN** an upsert is performed for novel_id "narou_n1234ab" with file_name "001_chapter1.txt" and no prior row exists
- **THEN** a new row SHALL be inserted with the provided novel_id, file_name "001_chapter1.txt", and the current timestamp as updated_at

#### Scenario: Replacing existing progress
- **WHEN** an upsert is performed for novel_id "narou_n1234ab" with file_name "005_chapter5.txt" and a prior row already exists
- **THEN** the existing row SHALL be updated to file_name "005_chapter5.txt" and the current timestamp as updated_at
- **AND** no duplicate row SHALL be created

### Requirement: Read reading progress
The system SHALL provide a lookup operation that returns the single reading progress record for a given novel, or null when no record exists. The returned record SHALL expose `file_name` (no absolute path).

#### Scenario: Novel has a progress record
- **WHEN** the reading progress is requested for novel_id "narou_n1234ab" which has a row stored
- **THEN** the operation SHALL return that row's file_name

#### Scenario: Novel has no progress record
- **WHEN** the reading progress is requested for novel_id "narou_unknown" which has no row stored
- **THEN** the operation SHALL return null

### Requirement: Auto-save on file selection
When the user opens a file inside a novel folder, the system SHALL upsert that file as the novel's reading progress, storing the file's `file_name`. The save SHALL be triggered whenever `selectedFileProvider` transitions to a non-null value while the current directory resolves to a non-null novel id. The novel id SHALL be derived with the shared nesting-aware rule `resolveNovelId` (nearest registered ancestor folder's leaf name = `folder_name`), NOT the first path segment under the library root. Selections made while no novel id can be resolved (library root, or a path with no registered ancestor folder) SHALL NOT save progress.

#### Scenario: User selects a file inside a novel folder
- **WHEN** the user is inside the folder for novel_id "narou_n1234ab" and selects "003_chapter3.txt" via tap or external navigation
- **THEN** the `reading_progress` row for "narou_n1234ab" SHALL be upserted to file_name "003_chapter3.txt"

#### Scenario: User selects a file inside a nested novel folder
- **WHEN** the user is inside "/library/お気に入り/narou_n1234ab" (where "narou_n1234ab" is a registered novel nested under the organizational folder "お気に入り") and selects "003_chapter3.txt"
- **THEN** the `reading_progress` row SHALL be upserted under novel_id "narou_n1234ab" (the registered leaf name), NOT "お気に入り"

#### Scenario: Selection is cleared
- **WHEN** `selectedFileProvider` transitions from a non-null `FileEntry` to null (e.g., directory change clears the selection)
- **THEN** no upsert SHALL be performed (the existing progress row remains untouched)

#### Scenario: Selection happens at library root
- **WHEN** `currentDirectoryProvider` equals the library root path and `selectedFileProvider` somehow becomes non-null (defensive case)
- **THEN** no upsert SHALL be performed because no novel id can be resolved

#### Scenario: Selection inside an organizational folder with no registered ancestor
- **WHEN** the current directory is an organizational folder that is not itself a registered novel and has no registered novel ancestor, and a file is selected
- **THEN** no upsert SHALL be performed because `resolveNovelId` returns null

### Requirement: One-shot auto-open on novel folder entry
When the user navigates into a novel folder (i.e., `currentDirectoryProvider` transitions to a path that resolves to a non-null novel id via the shared nesting-aware rule `resolveNovelId`), the system SHALL look up that novel's reading progress and, if a record exists and a file whose name equals the stored `file_name` is currently present in the directory listing, SHALL set `selectedFileProvider` to that file exactly once. The match SHALL be performed on `file_name` against the current directory's listing (NOT on a persisted absolute path), so a moved or renamed novel folder still restores progress. Subsequent rebuilds or unrelated state changes SHALL NOT re-trigger the auto-open.

The novel id used for the lookup SHALL be derived with `resolveNovelId` (nearest registered ancestor folder's leaf name = `folder_name`), so nested novels resolve to their registered leaf name rather than the first path segment. The auto-open SHALL NOT fire when no novel id can be resolved (library root, or a path with no registered ancestor folder).

#### Scenario: Entering a novel folder with stored progress restores the file
- **WHEN** the user navigates from the library root into the folder for novel_id "narou_n1234ab"
- **AND** `reading_progress` contains a row for "narou_n1234ab" with file_name "003_chapter3.txt"
- **AND** "003_chapter3.txt" is present in the directory's text file listing
- **THEN** `selectedFileProvider` SHALL be set to the `FileEntry` for "003_chapter3.txt" exactly once

#### Scenario: Entering a moved or renamed novel folder still restores the file
- **WHEN** the novel folder for novel_id "narou_n1234ab" has been moved or renamed since progress was saved
- **AND** `reading_progress` contains a row for "narou_n1234ab" with file_name "003_chapter3.txt"
- **AND** "003_chapter3.txt" is present in the novel's current directory listing
- **THEN** `selectedFileProvider` SHALL be set to the `FileEntry` for "003_chapter3.txt" (the stale absolute path of the old location SHALL NOT prevent the match)

#### Scenario: Entering a nested novel folder resolves to the registered leaf id
- **WHEN** the user navigates into "/library/お気に入り/narou_n1234ab" (a registered novel nested under "お気に入り")
- **AND** `reading_progress` contains a row for "narou_n1234ab"
- **THEN** the lookup SHALL use novel_id "narou_n1234ab" and restore the stored file if present

#### Scenario: Entering a novel folder with no stored progress
- **WHEN** the user navigates into a novel folder that has no `reading_progress` row
- **THEN** `selectedFileProvider` SHALL remain unchanged (typically null) and no automatic selection SHALL occur

#### Scenario: Stored file is no longer present
- **WHEN** the user navigates into the folder for novel_id "narou_n1234ab"
- **AND** `reading_progress` points to file_name "005_chapter5.txt"
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
