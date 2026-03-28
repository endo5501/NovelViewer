## MODIFIED Requirements

### Requirement: TTS audio database initialization
The system SHALL create a `tts_audio.db` SQLite database in each novel folder when TTS audio storage is first accessed. The database SHALL follow the same pattern as `EpisodeCacheDatabase` (folder-path-based initialization). The database SHALL contain `tts_episodes` and `tts_segments` tables. The database SHALL be configured with `auto_vacuum = INCREMENTAL` to enable on-demand disk space reclamation after audio data deletion.

#### Scenario: Database created on first access
- **WHEN** TTS audio storage is accessed for a novel folder that does not yet contain `tts_audio.db`
- **THEN** the database file is created at `{novel_folder}/tts_audio.db` with the required schema and `auto_vacuum = INCREMENTAL` enabled

#### Scenario: Existing database reused
- **WHEN** TTS audio storage is accessed for a novel folder that already contains `tts_audio.db`
- **THEN** the existing database is opened without modification

#### Scenario: Existing database migrated to INCREMENTAL auto_vacuum
- **WHEN** TTS audio storage is accessed for an existing `tts_audio.db` at schema version 3 (without auto_vacuum)
- **THEN** the database is migrated to schema version 4 by setting `PRAGMA auto_vacuum = INCREMENTAL` and executing `VACUUM` to rebuild the database with the new mode enabled

## ADDED Requirements

### Requirement: Disk space reclamation after episode deletion
The system SHALL reclaim disk space after TTS episode deletion by executing `PRAGMA incremental_vacuum(0)` after a `deleteEpisode` operation. This removes all free pages from the database file, reducing its size on disk.

#### Scenario: Disk space reclaimed after episode deletion
- **WHEN** `deleteEpisode(episodeId)` is called and the episode and its segments are deleted
- **THEN** `PRAGMA incremental_vacuum(0)` is executed, and the database file size is reduced by the amount of freed pages

#### Scenario: No effect when no free pages exist
- **WHEN** `deleteEpisode(episodeId)` is called for an episode with no audio BLOBs (all segments had NULL audio_data)
- **THEN** `PRAGMA incremental_vacuum(0)` executes successfully with no change to file size
