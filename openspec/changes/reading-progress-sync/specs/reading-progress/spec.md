# Spec Delta

## MODIFIED Requirements

### Requirement: One-shot auto-open on novel folder entry
When the user navigates into a novel folder (i.e., `currentDirectoryProvider` transitions to a path that resolves to a non-null novel id via the shared nesting-aware rule `resolveNovelId`), the system SHALL look up that novel's reading progress and, if a record exists and a file whose name equals the stored `file_name` is currently present in the directory listing, SHALL set `selectedFileProvider` to that file exactly once. The match SHALL be performed on `file_name` against the current directory's listing (NOT on a persisted absolute path), so a moved or renamed novel folder still restores progress. After selection, the system SHALL restore the saved body position once through the reading-position capability, subject to explicit navigation priority and content validation. Subsequent rebuilds or unrelated state changes SHALL NOT re-trigger the auto-open.

The novel id used for the lookup SHALL be derived with `resolveNovelId` (nearest registered ancestor folder's leaf name = `folder_name`), so nested novels resolve to their registered leaf name rather than the first path segment. The auto-open SHALL NOT fire when no novel id can be resolved (library root, or a path with no registered ancestor folder).

When progress sync is enabled and signed in, the system SHALL reconcile the novel's progress received from other devices (as defined by `reading-progress-sync`) on folder entry BEFORE selecting any file, so that the selection's own upsert cannot alter the comparison. If the novel has no local progress record and a received record resolves to an episode file in the current listing, that record's file, body offset, and body hash SHALL be written as the local progress and the auto-open SHALL then proceed with it. If the novel has local progress, the auto-open SHALL proceed with the local progress, and any confirmation offered by `reading-progress-sync` SHALL be shown only after that selection.

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
- **AND** no progress received from another device resolves to a file in the listing (or sync is disabled or signed out)
- **THEN** `selectedFileProvider` SHALL remain unchanged (typically null) and no automatic selection SHALL occur

#### Scenario: Entering a novel folder with only another device's progress
- **WHEN** the user navigates into the folder for novel_id "narou_n1234ab" that has no `reading_progress` row
- **AND** progress received from another device points to episode 5, and "005_chapter5.txt" (effective episode 5) is in the listing
- **THEN** a `reading_progress` row for "narou_n1234ab" SHALL be written with file_name "005_chapter5.txt" and the received body offset and body hash
- **AND** `selectedFileProvider` SHALL be set to "005_chapter5.txt" exactly once and the received position SHALL be restored

#### Scenario: Local progress is opened before any confirmation
- **WHEN** the user navigates into a novel folder that has a `reading_progress` row
- **AND** a newer progress at a different position was received from another device
- **THEN** the file from the local row SHALL be selected first
- **AND** the comparison SHALL use the local progress as it was before that selection

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
