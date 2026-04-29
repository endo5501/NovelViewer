## Purpose

Store generated TTS audio per episode and segment in a per-novel-folder SQLite database, exposing typed DTOs and a Riverpod-managed lifetime so consumers do not pay re-open costs or unsafe Map casts.
## Requirements
### Requirement: TTS audio database initialization
The system SHALL create a `tts_audio.db` SQLite database in each novel folder when TTS audio storage is first accessed. The database SHALL follow the same pattern as `EpisodeCacheDatabase` (folder-path-based initialization). The database SHALL contain `tts_episodes` and `tts_segments` tables. The database SHALL be configured with `auto_vacuum = INCREMENTAL` to enable on-demand disk space reclamation after audio data deletion.

#### Scenario: Database created on first access
- **WHEN** TTS audio storage is accessed for a novel folder that does not yet contain `tts_audio.db`
- **THEN** the database file is created at `{novel_folder}/tts_audio.db` with the required schema and `auto_vacuum = INCREMENTAL` enabled

#### Scenario: Existing database reused
- **WHEN** TTS audio storage is accessed for a novel folder that already contains `tts_audio.db`
- **THEN** the existing database is opened without modification

#### Scenario: Existing database migrated to INCREMENTAL auto_vacuum
- **WHEN** TTS audio storage is accessed for an existing `tts_audio.db` without `auto_vacuum = INCREMENTAL`
- **THEN** the database is migrated by setting `PRAGMA auto_vacuum = INCREMENTAL` and executing `VACUUM` to rebuild the database with the new mode enabled. This migration is performed after database open (outside `onUpgrade`) because `VACUUM` cannot execute within a transaction.

### Requirement: TTS episodes table schema
The `tts_episodes` table SHALL store per-episode audio generation state with the following columns: `id` (INTEGER PRIMARY KEY AUTOINCREMENT), `file_name` (TEXT NOT NULL UNIQUE — the episode file name e.g. "0001_プロローグ.txt"), `sample_rate` (INTEGER NOT NULL — audio sample rate e.g. 24000), `status` (TEXT NOT NULL — "generating", "partial", or "completed"), `ref_wav_path` (TEXT — voice cloning reference WAV path, nullable), `text_hash` (TEXT — SHA-256 hash of the episode text content, nullable for backward compatibility), `created_at` (TEXT NOT NULL), `updated_at` (TEXT NOT NULL).

#### Scenario: Insert episode record when generation starts
- **WHEN** audio generation starts for episode "0001_プロローグ.txt" with text content hash "abc123..."
- **THEN** a record is inserted with status "generating", the configured sample_rate, text_hash, and current timestamp

#### Scenario: Update episode status on generation complete
- **WHEN** all segments for an episode have been generated
- **THEN** the episode status is updated to "completed" and `updated_at` is set to the current timestamp

#### Scenario: Update episode status to partial on stop
- **WHEN** generation is stopped before all segments are generated
- **THEN** the episode status is updated to "partial" and `updated_at` is set to the current timestamp

#### Scenario: file_name uniqueness enforced
- **WHEN** an attempt is made to insert a duplicate file_name
- **THEN** the operation fails with a uniqueness constraint violation

#### Scenario: Migrate existing database to add text_hash column
- **WHEN** an existing `tts_audio.db` database without the `text_hash` column is opened
- **THEN** the `text_hash` column is added via `ALTER TABLE` with NULL default, and existing episodes continue to function (NULL text_hash triggers regeneration on next access)

### Requirement: TTS segments table schema
The `tts_segments` table SHALL store per-sentence audio data with the following columns: `id` (INTEGER PRIMARY KEY AUTOINCREMENT), `episode_id` (INTEGER NOT NULL — foreign key to tts_episodes), `segment_index` (INTEGER NOT NULL — 0-based sentence order), `text` (TEXT NOT NULL — the sentence text, may be edited by user for pronunciation correction), `text_offset` (INTEGER NOT NULL — position in original text), `text_length` (INTEGER NOT NULL — length in original text), `audio_data` (BLOB — WAV file bytes with header, NULL when segment has no generated audio), `sample_count` (INTEGER — number of audio samples, NULL when segment has no generated audio), `ref_wav_path` (TEXT — voice cloning reference for this segment, nullable), `memo` (TEXT — user memo for future control instruction support, nullable), `created_at` (TEXT NOT NULL). A unique index SHALL exist on `(episode_id, segment_index)`. A foreign key constraint on `episode_id` SHALL reference `tts_episodes(id)` with CASCADE delete.

#### Scenario: Insert segment with WAV BLOB
- **WHEN** a sentence audio is generated and saved
- **THEN** a record is inserted with the WAV binary data as BLOB, segment_index, text metadata, and sample_count

#### Scenario: Insert segment without audio (edit-only record)
- **WHEN** a user edits segment text in the edit dialog for a segment that has no existing DB record
- **THEN** a record is inserted with the edited text, audio_data=NULL, sample_count=NULL, and the provided text_offset and text_length

#### Scenario: Cascade delete segments when episode deleted
- **WHEN** an episode record is deleted from `tts_episodes`
- **THEN** all associated segment records are automatically deleted

#### Scenario: Segment ordering by index
- **WHEN** segments for an episode are queried
- **THEN** they are returned ordered by `segment_index` ascending

#### Scenario: Migrate existing database to version 3
- **WHEN** an existing `tts_audio.db` database at version 2 is opened
- **THEN** the `tts_segments` table is recreated with `audio_data` and `sample_count` as nullable columns and `memo` column added, all existing data is preserved, and the unique index is recreated

### Requirement: TTS audio repository CRUD operations
The system SHALL provide a `TtsAudioRepository` class with methods to: create an episode record (with text_hash), insert segment records (with or without audio_data), update a segment's text (setting audio_data and sample_count to NULL), update a segment's audio_data and sample_count, update a segment's ref_wav_path, update a segment's memo, query episode status by file_name, retrieve all segments for an episode ordered by segment_index, find a segment by text_offset, get the count of stored segments for an episode, get the count of segments with non-NULL audio_data for an episode, delete a single segment by episode_id and segment_index, delete an episode (cascading to segments), and retrieve all episode statuses as a map of file_name to TtsEpisodeStatus. All read methods that return row data SHALL return typed DTO instances (`TtsEpisode`, `TtsSegment`) or `null`/empty collections; raw `Map<String, Object?>` SHALL NOT be returned across the repository boundary.

#### Scenario: Check if episode has audio
- **WHEN** `findEpisodeByFileName("0001_プロローグ.txt")` is called
- **THEN** a `TtsEpisode` instance is returned if the episode exists, or `null` if no audio has been generated

#### Scenario: Retrieve segments for playback
- **WHEN** `getSegments(episodeId)` is called for an episode with 15 segments
- **THEN** a `List<TtsSegment>` of length 15 is returned ordered by segment_index, each carrying typed `audioData` (or `null` if not generated)

#### Scenario: Find segment by text offset for position-based playback
- **WHEN** `findSegmentByOffset(episodeId, 19)` is called
- **THEN** the `TtsSegment` whose text_offset is the largest value <= 19 is returned

#### Scenario: Delete episode and all audio data
- **WHEN** `deleteEpisode(episodeId)` is called
- **THEN** the episode record and all associated segments are deleted from the database

#### Scenario: Get segment count for resume detection
- **WHEN** `getSegmentCount(episodeId)` is called for an episode with 5 stored segments
- **THEN** the count 5 is returned

#### Scenario: Create episode with text hash
- **WHEN** `createEpisode()` is called with fileName, sampleRate, status, and textHash
- **THEN** a new episode record is created with the provided text_hash value

#### Scenario: Update segment text with audio invalidation
- **WHEN** `updateSegmentText(episodeId, segmentIndex, newText)` is called for a segment with existing audio
- **THEN** the text is updated, audio_data and sample_count are set to NULL

#### Scenario: Insert segment without audio
- **WHEN** `insertSegment()` is called with audio_data=NULL and sample_count=NULL
- **THEN** a segment record is created with NULL audio fields

#### Scenario: Update segment audio after regeneration
- **WHEN** `updateSegmentAudio(episodeId, segmentIndex, audioData, sampleCount)` is called
- **THEN** the segment's audio_data and sample_count are updated with the new values

#### Scenario: Update segment ref_wav_path
- **WHEN** `updateSegmentRefWavPath(episodeId, segmentIndex, refWavPath)` is called
- **THEN** the segment's ref_wav_path is updated

#### Scenario: Update segment memo
- **WHEN** `updateSegmentMemo(episodeId, segmentIndex, memo)` is called
- **THEN** the segment's memo is updated

#### Scenario: Delete single segment
- **WHEN** `deleteSegment(episodeId, segmentIndex)` is called
- **THEN** only the specified segment record is deleted

#### Scenario: Get count of generated segments
- **WHEN** `getGeneratedSegmentCount(episodeId)` is called for an episode with 10 segments total, 7 having audio_data
- **THEN** the count 7 is returned

#### Scenario: Get all episode statuses
- **WHEN** `getAllEpisodeStatuses()` is called on a repository with episodes in various states
- **THEN** a `Map<String, TtsEpisodeStatus>` is returned mapping each episode's file_name to its status

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

### Requirement: TTS audio database closure
The system SHALL close the `tts_audio.db` database connection when the Riverpod provider entry holding the database is invalidated or when the owning `ProviderContainer` is disposed (e.g., the user navigates away from the current novel folder, or the application terminates).

#### Scenario: Close database when leaving novel
- **WHEN** the user navigates away from the current novel folder and the provider entry for that folder is invalidated
- **THEN** the `TtsAudioDatabase.close` is invoked via `ref.onDispose` and the underlying connection is released

### Requirement: TTS audio data transfer objects
The system SHALL expose typed data transfer objects for `tts_episodes` and `tts_segments` rows. The `TtsEpisode` class SHALL have typed fields for `id` (int), `fileName` (String), `sampleRate` (int), `status` (TtsEpisodeStatus enum), `refWavPath` (String?), `textHash` (String?), `createdAt` (DateTime), and `updatedAt` (DateTime). The `TtsSegment` class SHALL have typed fields for `id` (int), `episodeId` (int), `segmentIndex` (int), `text` (String), `textOffset` (int), `textLength` (int), `audioData` (Uint8List?), `sampleCount` (int?), `refWavPath` (String?), `memo` (String?), and `createdAt` (DateTime). Both classes SHALL provide a `fromRow(Map<String, Object?>)` factory that asserts column types and throws on unexpected schema.

#### Scenario: Build TtsEpisode from a complete row
- **WHEN** `TtsEpisode.fromRow` is called with a `Map<String, Object?>` containing all expected columns with valid types
- **THEN** a `TtsEpisode` instance is returned with all fields populated and the status string mapped to the corresponding `TtsEpisodeStatus` enum value

#### Scenario: TtsEpisode parsing rejects unexpected status value
- **WHEN** `TtsEpisode.fromRow` is called with a row whose `status` is not one of `"generating"`, `"partial"`, `"completed"`
- **THEN** a `FormatException` (or equivalent) is thrown so the inconsistency is not silently propagated

#### Scenario: Build TtsSegment with NULL audio
- **WHEN** `TtsSegment.fromRow` is called with a row whose `audio_data` and `sample_count` are NULL
- **THEN** the resulting `TtsSegment` has `audioData == null` and `sampleCount == null`

### Requirement: Reference WAV path tri-state resolution
The system SHALL provide a single `TtsRefWavResolver.resolve` helper that maps the stored `ref_wav_path` value (`null`, empty string, or non-empty path) to an effective reference WAV path according to the contract: `null` → fall back to caller-supplied default; empty string → no reference (explicit "none"); non-empty path → use as-is. Both `TtsStreamingController` and `TtsEditController` SHALL use this helper rather than reimplementing the tri-state logic.

#### Scenario: Stored value is null, fallback exists
- **WHEN** `resolve(storedPath: null, fallbackPath: '/voice/default.wav')` is called
- **THEN** the helper returns `'/voice/default.wav'`

#### Scenario: Stored value is empty string
- **WHEN** `resolve(storedPath: '', fallbackPath: '/voice/default.wav')` is called
- **THEN** the helper returns `null`, indicating that no reference WAV is to be used

#### Scenario: Stored value is a non-empty path
- **WHEN** `resolve(storedPath: '/voice/custom.wav', fallbackPath: '/voice/default.wav')` is called
- **THEN** the helper returns `'/voice/custom.wav'`

### Requirement: Riverpod-managed TTS audio database lifetime
The system SHALL expose a Riverpod `Provider.family<TtsAudioDatabase, String>` keyed by novel folder path. The provider SHALL ensure a single `TtsAudioDatabase` instance per folder for as long as the provider is alive in the current `ProviderContainer`, and SHALL close the database via `ref.onDispose` when the provider is invalidated or disposed.

#### Scenario: Same folder yields the same instance
- **WHEN** the provider family is read twice with the same folder path within a single container
- **THEN** the second read returns the same `TtsAudioDatabase` instance as the first (no re-open)

#### Scenario: Folder change invalidates previous instance
- **WHEN** the active novel folder changes from path A to path B and the system invalidates the family entry for A
- **THEN** the database for A is closed via the `onDispose` callback before any new query touches the family entry for B

#### Scenario: Container disposal closes all cached databases
- **WHEN** the `ProviderContainer` holding the family is disposed
- **THEN** every cached `TtsAudioDatabase` is closed without leaving open file handles

