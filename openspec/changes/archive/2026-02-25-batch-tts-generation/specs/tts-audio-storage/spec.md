## ADDED Requirements

### Requirement: TTS audio database initialization
The system SHALL create a `tts_audio.db` SQLite database in each novel folder when TTS audio storage is first accessed. The database SHALL follow the same pattern as `EpisodeCacheDatabase` (folder-path-based initialization). The database SHALL contain `tts_episodes` and `tts_segments` tables.

#### Scenario: Database created on first access
- **WHEN** TTS audio storage is accessed for a novel folder that does not yet contain `tts_audio.db`
- **THEN** the database file is created at `{novel_folder}/tts_audio.db` with the required schema

#### Scenario: Existing database reused
- **WHEN** TTS audio storage is accessed for a novel folder that already contains `tts_audio.db`
- **THEN** the existing database is opened without modification

### Requirement: TTS episodes table schema
The `tts_episodes` table SHALL store per-episode audio generation state with the following columns: `id` (INTEGER PRIMARY KEY AUTOINCREMENT), `file_name` (TEXT NOT NULL UNIQUE — the episode file name e.g. "0001_プロローグ.txt"), `sample_rate` (INTEGER NOT NULL — audio sample rate e.g. 24000), `status` (TEXT NOT NULL — "generating" or "completed"), `ref_wav_path` (TEXT — voice cloning reference WAV path, nullable), `created_at` (TEXT NOT NULL), `updated_at` (TEXT NOT NULL).

#### Scenario: Insert episode record when generation starts
- **WHEN** audio generation starts for episode "0001_プロローグ.txt"
- **THEN** a record is inserted with status "generating", the configured sample_rate, and current timestamp

#### Scenario: Update episode status on generation complete
- **WHEN** all segments for an episode have been generated
- **THEN** the episode status is updated to "completed" and `updated_at` is set to the current timestamp

#### Scenario: file_name uniqueness enforced
- **WHEN** an attempt is made to insert a duplicate file_name
- **THEN** the operation fails with a uniqueness constraint violation

### Requirement: TTS segments table schema
The `tts_segments` table SHALL store per-sentence audio data with the following columns: `id` (INTEGER PRIMARY KEY AUTOINCREMENT), `episode_id` (INTEGER NOT NULL — foreign key to tts_episodes), `segment_index` (INTEGER NOT NULL — 0-based sentence order), `text` (TEXT NOT NULL — the sentence text), `text_offset` (INTEGER NOT NULL — position in original text), `text_length` (INTEGER NOT NULL — length in original text), `audio_data` (BLOB NOT NULL — WAV file bytes with header), `sample_count` (INTEGER NOT NULL — number of audio samples), `ref_wav_path` (TEXT — voice cloning reference for this segment, nullable), `created_at` (TEXT NOT NULL). A unique index SHALL exist on `(episode_id, segment_index)`. A foreign key constraint on `episode_id` SHALL reference `tts_episodes(id)` with CASCADE delete.

#### Scenario: Insert segment with WAV BLOB
- **WHEN** a sentence audio is generated and saved
- **THEN** a record is inserted with the WAV binary data as BLOB, segment_index, text metadata, and sample_count

#### Scenario: Cascade delete segments when episode deleted
- **WHEN** an episode record is deleted from `tts_episodes`
- **THEN** all associated segment records are automatically deleted

#### Scenario: Segment ordering by index
- **WHEN** segments for an episode are queried
- **THEN** they are returned ordered by `segment_index` ascending

### Requirement: TTS audio repository CRUD operations
The system SHALL provide a `TtsAudioRepository` class with methods to: create an episode record, insert segment records, query episode status by file_name, retrieve all segments for an episode ordered by segment_index, find a segment by text_offset, and delete an episode (cascading to segments).

#### Scenario: Check if episode has audio
- **WHEN** `findEpisodeByFileName("0001_プロローグ.txt")` is called
- **THEN** the episode record is returned if it exists, or null if no audio has been generated

#### Scenario: Retrieve segments for playback
- **WHEN** `getSegments(episodeId)` is called for an episode with 15 segments
- **THEN** all 15 segments are returned ordered by segment_index, each containing WAV BLOB data

#### Scenario: Find segment by text offset for position-based playback
- **WHEN** `findSegmentByOffset(episodeId, 19)` is called
- **THEN** the segment whose text_offset is the largest value <= 19 is returned

#### Scenario: Delete episode and all audio data
- **WHEN** `deleteEpisode(episodeId)` is called
- **THEN** the episode record and all associated segments are deleted from the database

#### Scenario: Get segment count for progress tracking
- **WHEN** `getSegmentCount(episodeId)` is called during generation
- **THEN** the number of currently saved segments for that episode is returned

### Requirement: TTS audio database closure
The system SHALL close the `tts_audio.db` database connection when the novel folder is no longer active (e.g., user navigates away from the novel).

#### Scenario: Close database when leaving novel
- **WHEN** the user navigates away from the current novel folder
- **THEN** the TTS audio database connection is closed
