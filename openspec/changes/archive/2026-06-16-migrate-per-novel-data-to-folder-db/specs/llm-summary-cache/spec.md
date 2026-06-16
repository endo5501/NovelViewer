## MODIFIED Requirements

### Requirement: Snapshot-keyed summary storage
The system SHALL store LLM summary results in the `word_summaries` SQLite table **inside the per-folder `novel_data.db` of the analyzed novel**, keyed by `(word, covered_up_to_episode)`. The table SHALL NOT carry a `folder_name` column; the novel identity is conveyed by which folder's `novel_data.db` the row lives in. The `covered_up_to_episode` column SHALL be a non-NULL integer that represents the upper bound (inclusive) of source files included in the analysis, expressed as the numeric prefix extracted from the file name by the regular expression `^(\d+)`. The system SHALL ALSO persist `source_file` set to the file the user was viewing when the analysis ran (no-spoiler scope) or to the highest-prefix file in the folder at analysis time (full-scope), so that subsequent UI features can resolve a jump target back into the text.

#### Scenario: Save a snapshot up to current file
- **WHEN** LLM analysis completes for the word "アリス" in folder "my_novel" while viewing file "040_chapter.txt" using "解析開始(ネタバレなし)"
- **THEN** a row SHALL be inserted into "my_novel"'s `novel_data.db` `word_summaries` with `word="アリス"`, `covered_up_to_episode=40`, `source_file="040_chapter.txt"`, and current timestamps

#### Scenario: Save a snapshot covering all files
- **WHEN** LLM analysis completes for the word "アリス" in folder "my_novel" using "解析開始(ネタバレあり)" while the folder's highest-prefix file is "120_chapter.txt"
- **THEN** the row SHALL be inserted with `covered_up_to_episode=120` and `source_file="120_chapter.txt"`

#### Scenario: Independent snapshots for the same word at different points
- **WHEN** the user has previously analyzed "アリス" with `covered_up_to_episode=30` and now runs another analysis with `covered_up_to_episode=120`
- **THEN** both rows SHALL coexist independently in `word_summaries` (no overwrite), one per snapshot

#### Scenario: Re-analysis overwrites the matching snapshot
- **WHEN** a row with `(word, covered_up_to_episode) = ("アリス", 30)` already exists in the folder's `novel_data.db` and a new analysis writes the same pair
- **THEN** the existing row's `summary`, `source_file`, and `updated_at` SHALL be replaced; no duplicate row SHALL be created

### Requirement: Snapshot selection on word display
When the user views an occurrence of a cached word, the system SHALL look up all `word_summaries` rows for `word` **in the active novel's `novel_data.db`** and apply the snapshot selection rule before display. Let `C` be the numeric prefix of the currently viewed file and `{Sᵢ}` be the set of `covered_up_to_episode` values for the word. The default selection SHALL be `max{Sᵢ | Sᵢ ≤ C}` when that set is non-empty; otherwise the default SHALL be `min{Sᵢ}` and the consumer (e.g. the hover popup) SHALL be informed that the chosen snapshot is from a "future" file.

#### Scenario: Default to the most recent past snapshot
- **WHEN** the current file's prefix is `C=6` and snapshots exist at `{1, 3, 5, 9}`
- **THEN** the snapshot with `covered_up_to_episode=5` SHALL be selected by default

#### Scenario: No past snapshot exists — fall back to the earliest future
- **WHEN** the current file's prefix is `C=6` and snapshots exist at `{9, 10, 20}`
- **THEN** the snapshot with `covered_up_to_episode=9` SHALL be selected by default and flagged as "future"

#### Scenario: Single snapshot is selected regardless of position
- **WHEN** only one snapshot exists at `covered_up_to_episode=15` and `C=5`
- **THEN** that single snapshot SHALL be returned with the "future" flag set

### Requirement: Snapshot lookup API on repository
The `LlmSummaryRepository` SHALL be constructed with a folder-scoped `novel_data.db` handle and SHALL expose an operation to retrieve all snapshots for a `word` as an `int`-ascending list of `WordSummary` values. The operation SHALL NOT take a `folderName` argument (the handle is already folder-scoped). The legacy `findSummary(folder, word, summaryType)` API SHALL be removed.

#### Scenario: List snapshots in ascending order
- **WHEN** `findSnapshotsForWord(word="アリス")` is invoked against "my_novel"'s handle and rows exist with `covered_up_to_episode` values `[20, 5, 30]`
- **THEN** the returned list SHALL be `[5, 20, 30]` (sorted ascending by `covered_up_to_episode`)

#### Scenario: Empty list when no snapshots exist
- **WHEN** `findSnapshotsForWord` is invoked for a word with no cached rows
- **THEN** the returned list SHALL be empty (not null)

### Requirement: Delete operation removes all snapshots for a word
The repository SHALL provide a deletion operation that removes every row for a `word` (i.e., across all `covered_up_to_episode` values) within the active novel's `novel_data.db`. Per-snapshot deletion is NOT in scope for this change.

#### Scenario: Delete removes every snapshot
- **WHEN** snapshots exist at `[5, 20, 30]` for word "アリス" in "my_novel" and the user triggers deletion from the history panel
- **THEN** all three rows SHALL be removed from that folder's `word_summaries`
