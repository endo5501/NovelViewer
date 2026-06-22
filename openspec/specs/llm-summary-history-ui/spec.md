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
Each history entry SHALL show the analyzed word, a snapshot-count badge indicating how many `word_summaries` rows exist for that `(folder_name, word)`, a preview of the most recently updated snapshot's summary text (truncated when long), and the most recent `updated_at` across all of the word's snapshots. The entry SHALL remain a single row per word regardless of how many snapshots exist (the multiple snapshots are exposed via the right-click menu, not via separate rows).

#### Scenario: Display entry with single snapshot
- **WHEN** the word "ボブ" has exactly one snapshot for the active novel
- **THEN** the entry SHALL display the word "ボブ", a badge reading "1スナップショット" (or a locale-appropriate compact form such as "×1"), the snapshot's summary preview, and the snapshot's `updated_at`

#### Scenario: Display entry with multiple snapshots
- **WHEN** the word "アリス" has three snapshots (`covered_up_to_episode=3`, `10`, `20`) for the active novel
- **THEN** the entry SHALL display the word "アリス" as a single row with a badge reading "3スナップショット" (or "×3"), a preview of the most recently updated snapshot, and the most recent `updated_at` across the three rows

#### Scenario: Long summary is truncated in preview
- **WHEN** the preview summary exceeds the available width of the entry row
- **THEN** the preview SHALL be truncated with an ellipsis so the layout remains a single row

### Requirement: History list sort order
History entries SHALL be sorted by the most recent `updated_at` across the word's snapshots in descending order (most recently updated first).

#### Scenario: Sort by updated_at descending
- **WHEN** the history panel renders for an active novel with three cached words whose most-recent-snapshot `updated_at` values are 10:00, 12:00, and 14:00 respectively
- **THEN** the entries SHALL be displayed in the order 14:00, 12:00, 10:00 from top to bottom

#### Scenario: Multi-snapshot entry uses latest updated_at for sorting
- **WHEN** a word "アリス" has snapshots whose `updated_at` values are 10:00, 13:00, and 16:00
- **THEN** that entry SHALL be sorted as if its `updated_at` were 16:00

### Requirement: Click jumps to first occurrence in source file
The user SHALL be able to click a history entry to open its source file and scroll to the first occurrence of the cached word within that file. The source file resolution SHALL use the `source_file` from the snapshot with the highest `covered_up_to_episode` that has a non-NULL `source_file`; if no snapshot has a `source_file`, the click SHALL be a no-op (the entry SHALL be visually indicated as not jumpable).

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

### Requirement: Delete entry via context menu
The user SHALL be able to right-click a history entry to open a context menu with a "削除" option. Selecting "削除" SHALL remove every snapshot row for `(folder_name=active novel, word=entry's word)` from `word_summaries`. The list SHALL refresh to reflect the deletion. Per-snapshot deletion SHALL NOT be exposed in this UI.

#### Scenario: Right-click shows context menu
- **WHEN** the user right-clicks a history entry
- **THEN** a context menu SHALL appear with a "削除" option

#### Scenario: Delete removes every snapshot for the word
- **WHEN** the user selects "削除" on an entry for the word "アリス" with three snapshots
- **THEN** all three rows for `(folder_name=active novel, word="アリス")` SHALL be deleted from `word_summaries`

#### Scenario: Delete refreshes the list
- **WHEN** a delete completes successfully
- **THEN** the history panel SHALL refresh and the deleted entry SHALL no longer appear

#### Scenario: Delete reflects in mark rendering
- **WHEN** the user deletes a history entry for a word that was being marked in the text viewer
- **THEN** the marks for that word SHALL be removed from the text viewer on the next render

### Requirement: Copy summary text from history entry context menu
The right-click context menu on a history entry SHALL include a "コピー" item that opens a submenu listing one entry per existing snapshot. Each submenu entry SHALL be labeled "Xファイル時点の要約をコピー" (where X is the snapshot's `covered_up_to_episode`) and SHALL be sorted in ascending `covered_up_to_episode` order. Selecting a submenu entry SHALL copy the corresponding snapshot's `summary` text to the OS clipboard and display a brief feedback (e.g., a SnackBar with text such as "クリップボードにコピーしました"). When the number of snapshots exceeds 8, only the 8 most recently updated snapshots SHALL be listed (this limit is not expected to be hit in practice). No `word_summaries` row SHALL be modified, deleted, or re-ordered as a result of a copy operation.

#### Scenario: Copy submenu lists every snapshot
- **WHEN** the user right-clicks an entry for the word "アリス" with snapshots at `covered_up_to_episode = {3, 10, 20}`
- **THEN** the context menu SHALL include a "コピー▶" item
- **AND** opening that submenu SHALL display the entries "3ファイル時点の要約をコピー", "10ファイル時点の要約をコピー", "20ファイル時点の要約をコピー" in that order

#### Scenario: Single-snapshot entry shows a single submenu item
- **WHEN** the user right-clicks an entry whose word has only one snapshot at `covered_up_to_episode=5`
- **THEN** the "コピー▶" submenu SHALL contain exactly one item "5ファイル時点の要約をコピー"

#### Scenario: Submenu caps the visible count at 8
- **WHEN** the user right-clicks an entry whose word has 12 snapshots
- **THEN** the "コピー▶" submenu SHALL display the 8 most recently updated snapshots' copy entries (sorted ascending by `covered_up_to_episode`)

#### Scenario: Selecting a copy entry writes summary to clipboard
- **WHEN** the user selects "10ファイル時点の要約をコピー"
- **THEN** the `summary` text of the snapshot at `covered_up_to_episode=10` for that word SHALL be written to the OS clipboard
- **AND** a brief feedback (e.g., SnackBar) SHALL confirm the copy

#### Scenario: Copy operation does not modify history rows
- **WHEN** the user selects any copy entry from the submenu
- **THEN** no `word_summaries` rows SHALL be modified, deleted, or re-ordered
- **AND** the history panel SHALL NOT refresh as a result of the copy

### Requirement: 履歴コンテキストメニューからの詳細表示

履歴エントリの右クリックコンテキストメニューは、既存の「コピー」「削除」に加えて「詳細を表示」項目を含まなければならない（SHALL）。「詳細を表示」を選択すると、そのエントリの単語に対する read-only の詳細ダイアログ（`llm-summary-history-detail-view` で定義）が開かれる。この操作はいかなる `word_summaries`／`fact_cache` 行も変更・削除・並べ替えしてはならず（SHALL NOT）、履歴パネルを再読み込みしない。

#### Scenario: コンテキストメニューに詳細項目が表示される

- **WHEN** ユーザーが履歴エントリ「アリス」を右クリックする
- **THEN** コンテキストメニューに「コピー▶」「詳細を表示」「削除」が表示される

#### Scenario: 詳細を表示を選ぶとダイアログが開く

- **WHEN** ユーザーがコンテキストメニューで「詳細を表示」を選択する
- **THEN** 単語「アリス」の詳細ダイアログが開く

#### Scenario: 詳細表示は履歴行を変更しない

- **WHEN** ユーザーが「詳細を表示」を選択し詳細ダイアログを開いて閉じる
- **THEN** `word_summaries` および `fact_cache` の行は一切変更・削除・並べ替えされない
- **AND** 履歴パネルはこの操作を理由に再読み込みされない

