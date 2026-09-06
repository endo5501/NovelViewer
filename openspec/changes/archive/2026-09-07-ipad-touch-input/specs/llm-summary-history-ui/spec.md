## MODIFIED Requirements

### Requirement: Delete entry via context menu
The user SHALL be able to right-click **or long-press** a history entry to open a context menu with a "削除" option. The menu the long press opens SHALL be identical to the one the right click opens. The long press SHALL apply only to pointers that have no secondary button, so that a mouse held down on an entry still jumps to it rather than opening the menu. Selecting "削除" SHALL remove every snapshot row for `(folder_name=active novel, word=entry's word)` from `word_summaries`. The list SHALL refresh to reflect the deletion. Per-snapshot deletion SHALL NOT be exposed in this UI.

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

#### Scenario: Delete refreshes the list
- **WHEN** a delete completes successfully
- **THEN** the history panel SHALL refresh and the deleted entry SHALL no longer appear

#### Scenario: Delete reflects in mark rendering
- **WHEN** the user deletes a history entry for a word that was being marked in the text viewer
- **THEN** the marks for that word SHALL be removed from the text viewer on the next render
