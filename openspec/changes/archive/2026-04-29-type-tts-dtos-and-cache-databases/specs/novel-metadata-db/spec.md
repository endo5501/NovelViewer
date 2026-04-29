## ADDED Requirements

### Requirement: Metadata database preserves data on open failure
The novel metadata database (`novel_metadata.db`) SHALL NOT be automatically deleted or recreated when its open operation fails. Failures SHALL be logged at WARNING level via `Logger('novel_metadata_db')` and rethrown so that the caller (typically application startup) becomes aware of the inconsistency. This requirement reflects that novel metadata (titles, library entries, bookmarks) is non-reproducible user data, distinct from the reproducible local-folder databases (TTS audio, dictionary, episode cache).

#### Scenario: Open failure does not delete the database
- **WHEN** `NovelDatabase` calls the shared open helper and the database file is corrupt
- **THEN** a WARNING-level `LogRecord` is emitted on `Logger('novel_metadata_db')`, the original exception is rethrown, and the database file remains on disk so the user can attempt manual recovery or contact support

#### Scenario: Helper invocation uses deleteOnFailure=false
- **WHEN** `NovelDatabase` invokes the shared `openOrResetDatabase` helper
- **THEN** the call passes `deleteOnFailure: false`, distinguishing it from `TtsAudioDatabase`, `TtsDictionaryDatabase`, and `EpisodeCacheDatabase`
