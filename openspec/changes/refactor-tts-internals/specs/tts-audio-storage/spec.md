## MODIFIED Requirements

### Requirement: Disk space reclamation after episode deletion
The system SHALL reclaim disk space after TTS episode deletion by executing `PRAGMA incremental_vacuum(0)` on the affected database. The reclaim SHALL NOT run synchronously inside `deleteEpisode`. Instead, `deleteEpisode` SHALL mark the database's folder as "vacuum-pending" and the actual `incremental_vacuum(0)` SHALL run when the application transitions to `AppLifecycleState.detached` (i.e., on app exit) for every folder that was marked dirty during the session. The repository SHALL retain a public `reclaimSpace()` method for explicit callers (e.g., a future "reclaim disk space" UI action).

#### Scenario: deleteEpisode does not run vacuum synchronously
- **WHEN** `deleteEpisode(episodeId)` is called
- **THEN** the episode and segments are deleted, the folder is marked vacuum-pending in the in-session lifecycle tracker, and `incremental_vacuum(0)` is NOT executed in the same call

#### Scenario: vacuum runs on app exit for marked folders
- **WHEN** the application transitions to `AppLifecycleState.detached` and one or more folders were marked vacuum-pending during the session
- **THEN** `incremental_vacuum(0)` is executed once per marked folder, reclaiming free pages from each database file

#### Scenario: vacuum is idempotent across re-deletes
- **WHEN** `deleteEpisode` is called multiple times for the same folder during one session
- **THEN** the folder is marked vacuum-pending only once and the exit-time vacuum runs exactly once

#### Scenario: explicit reclaimSpace remains callable
- **WHEN** caller code (e.g., a future UI button) calls `TtsAudioRepository.reclaimSpace()` directly
- **THEN** `incremental_vacuum(0)` is executed immediately on that database, regardless of the lifecycle marker state

#### Scenario: No effect when no free pages exist
- **WHEN** `incremental_vacuum(0)` runs at exit for a folder where all deleted episodes had NULL audio_data (no BLOBs to free)
- **THEN** the operation completes successfully with no change to file size
