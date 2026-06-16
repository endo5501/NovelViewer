## MODIFIED Requirements

### Requirement: Novel metadata storage
The system SHALL store novel metadata in a `novels` table with the following fields: auto-increment ID, site type, novel ID, title, URL, folder name, episode count, downloaded timestamp, and updated timestamp. The system SHALL provide a method to delete a novel record by folder name. Deleting a novel record SHALL NOT cascade to `word_summaries`, `fact_cache`, or `bookmarks`, because those tables no longer live in `novel_metadata.db` (they are removed with the novel's folder via its `novel_data.db`).

#### Scenario: Novel metadata is registered after download
- **WHEN** a novel download completes successfully
- **THEN** a record is inserted into the novels table with the site type, novel ID, title, source URL, ID-based folder name, episode count, and current timestamp

#### Scenario: Duplicate novel download updates existing record
- **WHEN** a novel with the same site type and novel ID is downloaded again
- **THEN** the existing record is updated with the new title, episode count, and updated timestamp instead of creating a duplicate

#### Scenario: Delete novel by folder name
- **WHEN** NovelRepository.deleteByFolderName(folderName) is called
- **THEN** the novel record matching the given folder name is deleted from the novels table
- **AND** no `word_summaries` / `fact_cache` / `bookmarks` rows are touched in `novel_metadata.db` (those tables no longer exist there)

### Requirement: Metadata database preserves data on open failure
The novel metadata database (`novel_metadata.db`) SHALL NOT be automatically deleted or recreated when its open operation fails. Failures SHALL be logged at WARNING level via `Logger('novel_metadata_db')` and rethrown so that the caller (typically application startup) becomes aware of the inconsistency. This requirement reflects that novel metadata (titles, library entries, reading progress) is non-reproducible user data, distinct from the reproducible local-folder databases (TTS audio, dictionary, episode cache). The per-folder `novel_data.db`, which now holds bookmarks, applies the same preservation contract on its own side.

#### Scenario: Open failure does not delete the database
- **WHEN** `NovelDatabase` calls the shared open helper and the database file is corrupt
- **THEN** a WARNING-level `LogRecord` is emitted on `Logger('novel_metadata_db')`, the original exception is rethrown, and the database file remains on disk so the user can attempt manual recovery or contact support

#### Scenario: Helper invocation uses deleteOnFailure=false
- **WHEN** `NovelDatabase` invokes the shared `openOrResetDatabase` helper
- **THEN** the call passes `deleteOnFailure: false`, distinguishing it from `TtsAudioDatabase`, `TtsDictionaryDatabase`, and `EpisodeCacheDatabase`

## ADDED Requirements

### Requirement: v8→v9 migrates then drops per-novel tables
The system SHALL upgrade `novel_metadata.db` to schema version 9. The v8→v9 `onUpgrade` SHALL, within its transaction, copy the `word_summaries`, `fact_cache`, and `bookmarks` rows into each novel's `novel_data.db` (idempotent upsert) and then, only after all extant folders are copied, drop those three tables. The `novels` and `reading_progress` tables SHALL be retained. The `user_version` SHALL be the sole completion flag: it is committed to 9 only when the `onUpgrade` transaction succeeds, so an interrupted migration rolls back to `user_version=8` and resumes on the next launch without data loss.

#### Scenario: Migrated tables are dropped at the end of the v8→v9 upgrade
- **WHEN** the application starts with `novel_metadata.db` at `user_version=8` and the v8→v9 `onUpgrade` copies every extant folder's rows successfully
- **THEN** `word_summaries`, `fact_cache`, and `bookmarks` SHALL be dropped as the final step
- **AND** the `novels` and `reading_progress` tables SHALL remain intact
- **AND** `user_version` SHALL be committed to 9

#### Scenario: Interrupted upgrade rolls back and resumes
- **WHEN** the v8→v9 `onUpgrade` is interrupted before completing
- **THEN** the `novel_metadata.db` transaction SHALL roll back, leaving `user_version=8` and the three global tables intact
- **AND** the next launch SHALL re-run the v8→v9 `onUpgrade`, with already-copied rows deduplicated by upsert
