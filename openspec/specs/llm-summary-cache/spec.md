## Purpose

SQLite-backed cache (`word_summaries` table) for LLM word summaries, keyed by snapshot triplet `(folder_name, word, covered_up_to_episode)`. Loads snapshots on word selection, supports multi-snapshot retrieval, enforces a minimum word length, and migrates the schema from v4 (legacy `summary_type` keying) to v5 (snapshot keying).
## Requirements
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

### Requirement: Database schema migration v4 → v5
The system SHALL upgrade the database from version 4 to version 5 by replacing the legacy `word_summaries` schema (`PK: folder_name, word, summary_type`) with the new snapshot schema (`PK: folder_name, word, covered_up_to_episode`). Existing rows SHALL be transformed by the rules below, preserving every row whenever possible.

| V4 row condition | `covered_up_to_episode` value |
|------------------|-------------------------------|
| `summary_type='no_spoiler'` AND `source_file` matches `^(\d+)` | the captured integer |
| `summary_type='no_spoiler'` AND `source_file` is non-NULL with no numeric prefix | the 1-origin lexical sort position of `source_file` within the folder's text files at migration time |
| `summary_type='no_spoiler'` AND `source_file IS NULL` | `1` (fallback) |
| `summary_type='spoiler'` AND `source_file IS NULL` | `novels.episode_count` for the matching `folder_name`, or `1` when that value is `NULL` or `0` |
| `summary_type='spoiler'` AND `source_file` is non-NULL | `max(prefix_or_lexical_rank, novels.episode_count)` (with `episode_count` treated as `1` when missing) |

When two V4 rows for the same `(folder_name, word)` (one no-spoiler and one spoiler) yield the same `covered_up_to_episode` after transformation, the row with the newer `updated_at` SHALL be kept and the older one SHALL be dropped. The migration SHALL be implemented as a one-way upgrade; rolling back to v4 is not supported.

#### Scenario: no-spoiler row with numeric prefix
- **WHEN** a v4 row has `summary_type='no_spoiler'`, `source_file='030_chapter.txt'`
- **THEN** the migrated v5 row SHALL have `covered_up_to_episode=30`

#### Scenario: no-spoiler row without numeric prefix
- **WHEN** a v4 row has `summary_type='no_spoiler'`, `source_file='intro.txt'`, and the folder's text files sorted lexically are `[intro.txt, part1.txt, part2.txt]`
- **THEN** the migrated v5 row SHALL have `covered_up_to_episode=1`

#### Scenario: spoiler row with NULL source_file
- **WHEN** a v4 row has `summary_type='spoiler'`, `source_file=NULL`, and `novels.episode_count=10` for the same folder
- **THEN** the migrated v5 row SHALL have `covered_up_to_episode=10` and `source_file=NULL`

#### Scenario: spoiler row with missing episode_count
- **WHEN** a v4 row has `summary_type='spoiler'`, `source_file=NULL`, and `novels.episode_count=0` for the same folder
- **THEN** the migrated v5 row SHALL have `covered_up_to_episode=1`

#### Scenario: spoiler row with non-NULL source_file
- **WHEN** a v4 row has `summary_type='spoiler'`, `source_file='025_chapter.txt'`, and `novels.episode_count=40`
- **THEN** the migrated v5 row SHALL have `covered_up_to_episode=40` (`max(25, 40)`)

#### Scenario: Collision between converted no-spoiler and spoiler rows
- **WHEN** the v4 table contains a `no_spoiler` row for `("my_novel", "アリス")` with `source_file='030_chapter.txt'` (updated_at=10:00) AND a `spoiler` row for the same `(folder, word)` with `source_file='030_chapter.txt'` (updated_at=12:00)
- **THEN** both yield `covered_up_to_episode=30`; only the row with `updated_at=12:00` SHALL survive in v5

#### Scenario: Migration preserves data on failure
- **WHEN** the v4 → v5 migration encounters an error mid-transform
- **THEN** the original `word_summaries` v4 table SHALL remain intact; the new schema SHALL NOT be partially applied

#### Scenario: Fresh install creates the v5 schema directly
- **WHEN** the application starts with no existing database
- **THEN** `onCreate` SHALL create the `word_summaries` table with the v5 schema (`covered_up_to_episode INTEGER NOT NULL`, no `summary_type` column) and the corresponding unique index `(folder_name, word, covered_up_to_episode)`

### Requirement: Minimum word length for cache writes
The system SHALL refuse to write a new `word_summaries` row when the analyzed word is shorter than 2 characters. This SHALL be enforced at the repository layer so that downstream features (mark rendering, history panel) do not have to filter 1-character entries at render time.

#### Scenario: 1-character word write is rejected
- **WHEN** the analysis pipeline attempts to save a summary for the word "の"
- **THEN** the save SHALL be rejected without writing a row, and the caller SHALL receive a clear failure signal (exception or error result)

#### Scenario: 2-character word write succeeds
- **WHEN** the analysis pipeline saves a summary for the word "聖印"
- **THEN** the save SHALL succeed normally

