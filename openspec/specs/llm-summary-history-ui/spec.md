## Purpose

LLM analysis history panel in the left column: a third tab ("解析履歴") alongside "ファイル" and "ブックマーク" that lists cached `word_summaries` entries for the active novel, supports click-to-jump back to the source file, and lets the user delete history entries via a context menu.

## Requirements

### Requirement: Left column history tab
The left column SHALL include a third tab labeled "解析履歴" alongside "ファイル" and "ブックマーク". The user SHALL be able to switch to this tab by tapping on it. Tab switching SHALL preserve the state of the other tabs (current directory, bookmark list scroll position).

#### Scenario: User switches to history tab
- **WHEN** the user taps the "解析履歴" tab
- **THEN** the analysis history panel SHALL be displayed below the tab bar
- **AND** the "解析履歴" tab SHALL be visually indicated as active

#### Scenario: User switches back from history tab
- **WHEN** the user switches away from the "解析履歴" tab to another tab
- **THEN** the other tab's panel SHALL be displayed with its prior state preserved

### Requirement: History entries scoped to active novel
The analysis history panel SHALL display only `word_summaries` entries whose `folder_name` matches the currently opened novel (the folder identified by `currentDirectoryProvider`). When no novel is active (user is at library root), a message SHALL be displayed instead of an entry list.

#### Scenario: Display entries for active novel
- **WHEN** the user is browsing files within a novel folder and switches to the history tab
- **THEN** only the `word_summaries` rows whose `folder_name` matches the active novel SHALL be displayed

#### Scenario: No active novel
- **WHEN** the user is at the library root directory and switches to the history tab
- **THEN** a message "作品フォルダを選択してください" SHALL be displayed

#### Scenario: No entries exist
- **WHEN** the user switches to the history tab and the active novel has no cached summaries
- **THEN** a message "解析履歴がありません" SHALL be displayed

### Requirement: History entry display
Each history entry SHALL show the analyzed word, a type indicator (なし / あり / 両), a preview of the cached summary text (truncated when long), and the `updated_at` timestamp. When a word has both a no-spoiler and a spoiler cache, the system SHALL collapse them into a single entry with the "両" indicator and display the most recent `updated_at` of the two.

#### Scenario: Display entry with single type
- **WHEN** the word "ボブ" has only a no-spoiler cache for the active novel
- **THEN** the entry SHALL display the word "ボブ", a "なし" type indicator, the no-spoiler summary preview, and the no-spoiler `updated_at`

#### Scenario: Display entry with both types
- **WHEN** the word "アリス" has both a no-spoiler cache and a spoiler cache for the active novel
- **THEN** the entry SHALL display the word "アリス" as a single row with a "両" indicator, a summary preview, and the most recent `updated_at` of the two rows

#### Scenario: Long summary is truncated in preview
- **WHEN** the cached summary exceeds the available width of the entry row
- **THEN** the preview SHALL be truncated with an ellipsis so the layout remains a single row

### Requirement: History list sort order
History entries SHALL be sorted by `updated_at` in descending order (most recently updated first). For "両" entries the sort key SHALL be the most recent `updated_at` of the two underlying rows.

#### Scenario: Sort by updated_at descending
- **WHEN** the history panel renders for an active novel with three cached words updated at 10:00, 12:00, and 14:00 respectively
- **THEN** the entries SHALL be displayed in the order 14:00, 12:00, 10:00 from top to bottom

#### Scenario: Two-type entry uses latest updated_at for sorting
- **WHEN** a word "アリス" has a no-spoiler cache updated at 10:00 and a spoiler cache updated at 16:00
- **THEN** the merged "両" entry SHALL be sorted as if its `updated_at` were 16:00

### Requirement: Click jumps to first occurrence in source file
The user SHALL be able to click a history entry to open its source file and scroll to the first occurrence of the cached word within that file. The source file resolution SHALL use the entry's `source_file`: the no-spoiler row's `source_file` when present; otherwise the spoiler row's `source_file`. When neither row has a `source_file`, the click SHALL be a no-op (the entry SHALL be visually indicated as not jumpable).

#### Scenario: Jump using no-spoiler source file
- **WHEN** the user clicks an entry whose no-spoiler row has `source_file="040_chapter.txt"`
- **THEN** "040_chapter.txt" SHALL be opened in the text viewer and the viewer SHALL scroll to the first occurrence of the cached word within that file

#### Scenario: Jump using spoiler source file fallback
- **WHEN** the user clicks an entry whose no-spoiler row is absent or has `source_file=NULL` and whose spoiler row has `source_file="060_chapter.txt"`
- **THEN** "060_chapter.txt" SHALL be opened in the text viewer and the viewer SHALL scroll to the first occurrence of the cached word within that file

#### Scenario: Entry without source file is not jumpable
- **WHEN** the user clicks an entry whose underlying rows all have `source_file=NULL` (legacy spoiler-only data)
- **THEN** the click SHALL NOT change the current file or scroll position
- **AND** the entry SHALL be displayed with a visual cue indicating it is not jumpable (e.g., reduced opacity or a small "未追跡" badge)

#### Scenario: Word not present in resolved source file
- **WHEN** the resolved `source_file` is opened but does not actually contain the cached word
- **THEN** the file SHALL be opened normally without scrolling, and no error dialog SHALL be shown

### Requirement: Delete entry via context menu
The user SHALL be able to right-click a history entry to open a context menu with a "削除" option. Selecting "削除" SHALL remove both the no-spoiler and the spoiler row for that word from the active novel (if either exists). The list SHALL refresh to reflect the deletion.

#### Scenario: Right-click shows context menu
- **WHEN** the user right-clicks a history entry
- **THEN** a context menu SHALL appear with a "削除" option

#### Scenario: Delete removes all type rows for the word
- **WHEN** the user selects "削除" on a "両" entry for the word "アリス"
- **THEN** both the no-spoiler row and the spoiler row for `(folder_name=active novel, word="アリス")` SHALL be deleted from `word_summaries`

#### Scenario: Delete refreshes the list
- **WHEN** a delete completes successfully
- **THEN** the history panel SHALL refresh and the deleted entry SHALL no longer appear

#### Scenario: Delete reflects in mark rendering
- **WHEN** the user deletes a history entry for a word that was being marked in the text viewer
- **THEN** the marks for that word SHALL be removed from the text viewer on the next render
