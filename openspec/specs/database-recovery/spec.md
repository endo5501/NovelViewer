# database-recovery Specification

## Purpose
TBD - created by archiving change type-tts-dtos-and-cache-databases. Update Purpose after archive.
## Requirements
### Requirement: Database open helper with explicit recovery policy
The system SHALL provide a shared helper `openOrResetDatabase` that opens a SQLite database and applies a caller-specified recovery policy when the open fails. The helper SHALL accept a `deleteOnFailure` parameter (default `false`) that controls whether a corrupt database file is deleted and recreated. The helper SHALL log the open failure at WARNING level via the caller-supplied `Logger` before any recovery action.

#### Scenario: Open succeeds normally
- **WHEN** `openOrResetDatabase` is called with a valid database file path and version
- **THEN** the database is opened and returned without invoking any recovery logic

#### Scenario: Open fails with deleteOnFailure=true
- **WHEN** `openOrResetDatabase` is called with `deleteOnFailure: true` and the existing database file is corrupt
- **THEN** the helper logs the failure at WARNING, deletes the file, and re-opens the database with the configured `onCreate` callback, returning a fresh database

#### Scenario: Open fails with deleteOnFailure=false
- **WHEN** `openOrResetDatabase` is called with `deleteOnFailure: false` (default) and the existing database file is corrupt
- **THEN** the helper logs the failure at WARNING and rethrows the original exception, preserving the database file on disk

### Requirement: Reproducible vs non-reproducible database recovery
Databases whose contents can be regenerated from external state (audio data from text, episode cache from re-download, dictionary from default) SHALL pass `deleteOnFailure: true` to the helper. Databases that store user-authored or non-regenerable data SHALL pass `deleteOnFailure: false`.

#### Scenario: TTS audio database uses delete-and-retry
- **WHEN** `TtsAudioDatabase` opens its database file
- **THEN** the call to `openOrResetDatabase` SHALL pass `deleteOnFailure: true` because audio data is reproducible by re-running TTS synthesis

#### Scenario: TTS dictionary database uses delete-and-retry
- **WHEN** `TtsDictionaryDatabase` opens its database file
- **THEN** the call to `openOrResetDatabase` SHALL pass `deleteOnFailure: true`

#### Scenario: Episode cache database uses delete-and-retry
- **WHEN** `EpisodeCacheDatabase` opens its database file
- **THEN** the call to `openOrResetDatabase` SHALL pass `deleteOnFailure: true`

#### Scenario: Novel metadata database preserves data on failure
- **WHEN** `NovelDatabase` opens its database file
- **THEN** the call to `openOrResetDatabase` SHALL pass `deleteOnFailure: false` because novel metadata (titles, bookmarks, library state) is non-reproducible

