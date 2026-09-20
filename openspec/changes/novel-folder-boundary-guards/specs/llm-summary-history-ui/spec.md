## MODIFIED Requirements

### Requirement: History entries scoped to active novel
The analysis history panel SHALL display only `word_summaries` entries belonging to the **registered novel folder resolved from the browser's current directory** — the nearest registered novel folder at or above it, by the same nesting-aware rule the bookmark panel uses to reach the same `novel_data.db`. The panel SHALL NOT treat the current directory as a novel folder merely because it is not the library root.

When no registered novel folder can be resolved — at the library root, and in any organizational folder with no registered novel folder among its ancestors — a message SHALL be displayed instead of an entry list, and the panel SHALL NOT open a `novel_data.db` for that folder. Opening one creates the file, so a folder that is not a novel folder would be left holding a novel's database.

#### Scenario: Display entries for active novel
- **WHEN** the user is browsing files within a novel folder and switches to the history tab
- **THEN** only the `word_summaries` rows whose `folder_name` matches the active novel SHALL be displayed

#### Scenario: Entries resolve from a nested novel folder
- **WHEN** the user is browsing a novel folder nested two or more levels below the library root and switches to the history tab
- **THEN** the entries of that novel folder SHALL be displayed, exactly as for a novel folder directly under the library root

#### Scenario: No active novel
- **WHEN** the user is at the library root directory and switches to the history tab
- **THEN** a message "作品フォルダを選択してください" SHALL be displayed

#### Scenario: No active novel in an organizational folder
- **WHEN** the user is in an organizational folder with no registered novel folder among its ancestors and switches to the history tab
- **THEN** a message "作品フォルダを選択してください" SHALL be displayed
- **AND** no `novel_data.db` SHALL be created in that folder

#### Scenario: No entries exist
- **WHEN** the user switches to the history tab and the active novel has no cached summaries
- **THEN** a message "解析履歴がありません" SHALL be displayed

### Requirement: Click jumps to first occurrence in source file
The user SHALL be able to click a history entry to open its source file and scroll to the first occurrence of the cached word within that file. The source file resolution SHALL use the `source_file` from the snapshot with the highest `covered_up_to_episode` that has a non-NULL `source_file`; if no snapshot has a `source_file`, the click SHALL be a no-op (the entry SHALL be visually indicated as not jumpable).

A snapshot's `source_file` is a file name recorded against the folder the episodes were read from, not against the novel folder that owns the database. The jump SHALL therefore resolve the file within the browser's current directory, even when the novel folder the history was read from is an ancestor of it.

#### Scenario: Jump using latest snapshot's source file
- **WHEN** the user clicks an entry whose highest-`covered_up_to_episode` snapshot has `source_file="040_chapter.txt"`
- **THEN** "040_chapter.txt" SHALL be opened in the text viewer and the viewer SHALL scroll to the first occurrence of the cached word within that file

#### Scenario: Jump falls back to next-highest with source_file
- **WHEN** the user clicks an entry whose highest-`covered_up_to_episode` snapshot has `source_file=NULL` and the next snapshot down has `source_file="060_chapter.txt"`
- **THEN** "060_chapter.txt" SHALL be opened in the text viewer and the viewer SHALL scroll to the first occurrence of the cached word

#### Scenario: Entry without any source file is not jumpable
- **WHEN** the user clicks an entry whose all snapshots have `source_file=NULL` (legacy migrated data)
- **THEN** the click SHALL NOT change the current file or scroll position
- **AND** the entry SHALL be displayed with a visual cue indicating it is not jumpable (e.g., reduced opacity or a small "未追跡" badge)

#### Scenario: Word not present in resolved source file
- **WHEN** the resolved `source_file` is opened but does not actually contain the cached word
- **THEN** the file SHALL be opened normally without scrolling, and no error dialog SHALL be shown
