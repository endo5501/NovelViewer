## MODIFIED Requirements

### Requirement: History entries scoped to active novel
The analysis history panel SHALL display only `word_summaries` entries belonging to the **registered novel folder the file browser is at**. The panel SHALL NOT treat the current directory as a novel folder merely because it is not the library root, and SHALL NOT treat a directory inside a novel folder as that novel.

Depth is irrelevant: a novel folder nested under organizational folders is still its own folder.

When the browser is not at a registered novel folder — at the library root, in an organizational folder, or in a subfolder inside a novel — a message SHALL be displayed instead of an entry list, and the panel SHALL NOT open a `novel_data.db` for that folder. Opening one creates the file, so a folder that is not a novel would be left holding a novel's database.

A subfolder inside a novel is excluded for a second reason: a snapshot's episode number and its `source_file` are both counted within the folder the browser is at, while the rows would land in the novel's database. Showing that novel's entries from a subfolder would offer jump targets that do not resolve there.

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

#### Scenario: No active novel in a subfolder inside a novel
- **WHEN** the user is in a subfolder inside a registered novel folder and switches to the history tab
- **THEN** a message "作品フォルダを選択してください" SHALL be displayed
- **AND** the novel's entries SHALL NOT be listed there
- **AND** no `novel_data.db` SHALL be created in the subfolder

#### Scenario: No entries exist
- **WHEN** the user switches to the history tab and the active novel has no cached summaries
- **THEN** a message "解析履歴がありません" SHALL be displayed

### Requirement: Delete entry via context menu
The user SHALL be able to right-click **or long-press** a history entry to open a context menu with a "削除" option. The menu the long press opens SHALL be identical to the one the right click opens. The long press SHALL apply only to pointers that have no secondary button, so that a mouse held down on an entry still jumps to it rather than opening the menu. Selecting "削除" SHALL remove every snapshot row for `(folder_name=active novel, word=entry's word)` from `word_summaries`. The list SHALL refresh to reflect the deletion. Per-snapshot deletion SHALL NOT be exposed in this UI.

The delete SHALL act on the novel folder the displayed list was read from, not on wherever the file browser has moved to since. The list and the entry in it belong to one novel; a delete that resolved its folder again could remove the word from a different novel's database than the one the user was looking at.

#### Scenario: Right-click shows context menu
- **WHEN** the user right-clicks a history entry
- **THEN** a context menu SHALL appear with a "削除" option

#### Scenario: Long press shows context menu
- **WHEN** the user long-presses a history entry with a finger or a stylus
- **THEN** the same context menu SHALL appear at the press position

#### Scenario: A slow mouse click still jumps to the entry
- **WHEN** the user holds the primary mouse button on a jumpable history entry past the long-press threshold and releases
- **THEN** no context menu SHALL appear and the entry SHALL be opened

#### Scenario: Delete removes every snapshot for the word
- **WHEN** the user selects "削除" on an entry for the word "アリス" with three snapshots
- **THEN** all three rows for `(folder_name=active novel, word="アリス")` SHALL be deleted from `word_summaries`

#### Scenario: Delete acts on the novel the list came from
- **WHEN** the file browser leaves the novel folder between the list being displayed and the delete being confirmed
- **THEN** the rows SHALL be deleted from the novel the list was read from

#### Scenario: Delete refreshes the list
- **WHEN** a delete completes successfully
- **THEN** the history panel SHALL refresh and the deleted entry SHALL no longer appear

#### Scenario: Delete reflects in mark rendering
- **WHEN** the user deletes a history entry for a word that was being marked in the text viewer
- **THEN** the marks for that word SHALL be removed from the text viewer on the next render
