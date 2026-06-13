## MODIFIED Requirements

### Requirement: Auto-save on file selection
When the user opens a file inside a novel folder, the system SHALL upsert that file as the novel's reading progress. The save SHALL be triggered whenever `selectedFileProvider` transitions to a non-null value while the current directory resolves to a non-null novel id. The novel id SHALL be derived with the shared nesting-aware rule `resolveNovelId` (nearest registered ancestor folder's leaf name = `folder_name`), NOT the first path segment under the library root. Selections made while no novel id can be resolved (library root, or a path with no registered ancestor folder) SHALL NOT save progress.

#### Scenario: User selects a file inside a novel folder
- **WHEN** the user is inside the folder for novel_id "narou_n1234ab" and selects "/library/narou_n1234ab/003_chapter3.txt" via tap or external navigation
- **THEN** the `reading_progress` row for "narou_n1234ab" SHALL be upserted to file_path "/library/narou_n1234ab/003_chapter3.txt"

#### Scenario: User selects a file inside a nested novel folder
- **WHEN** the user is inside "/library/お気に入り/narou_n1234ab" (where "narou_n1234ab" is a registered novel nested under the organizational folder "お気に入り") and selects "/library/お気に入り/narou_n1234ab/003_chapter3.txt"
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
When the user navigates into a novel folder (i.e., `currentDirectoryProvider` transitions to a path that resolves to a non-null novel id via the shared nesting-aware rule `resolveNovelId`), the system SHALL look up that novel's reading progress and, if a record exists and the recorded file is currently present in the directory listing, SHALL set `selectedFileProvider` to that file exactly once. Subsequent rebuilds or unrelated state changes SHALL NOT re-trigger the auto-open.

The novel id used for the lookup SHALL be derived with `resolveNovelId` (nearest registered ancestor folder's leaf name = `folder_name`), so nested novels resolve to their registered leaf name rather than the first path segment. The auto-open SHALL NOT fire when no novel id can be resolved (library root, or a path with no registered ancestor folder).

#### Scenario: Entering a novel folder with stored progress restores the file
- **WHEN** the user navigates from the library root into the folder for novel_id "narou_n1234ab"
- **AND** `reading_progress` contains a row for "narou_n1234ab" pointing to "/library/narou_n1234ab/003_chapter3.txt"
- **AND** "003_chapter3.txt" is present in the directory's text file listing
- **THEN** `selectedFileProvider` SHALL be set to the `FileEntry` for "003_chapter3.txt" exactly once

#### Scenario: Entering a nested novel folder resolves to the registered leaf id
- **WHEN** the user navigates into "/library/お気に入り/narou_n1234ab" (a registered novel nested under "お気に入り")
- **AND** `reading_progress` contains a row for "narou_n1234ab"
- **THEN** the lookup SHALL use novel_id "narou_n1234ab" and restore the stored file if present

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
