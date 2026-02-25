## MODIFIED Requirements

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

### Requirement: TTS audio repository CRUD operations
The system SHALL provide a `TtsAudioRepository` class with methods to: create an episode record (with text_hash), insert segment records, query episode status by file_name, retrieve all segments for an episode ordered by segment_index, find a segment by text_offset, get the count of stored segments for an episode, and delete an episode (cascading to segments).

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

#### Scenario: Get segment count for resume detection
- **WHEN** `getSegmentCount(episodeId)` is called for an episode with 5 stored segments
- **THEN** the count 5 is returned

#### Scenario: Create episode with text hash
- **WHEN** `createEpisode()` is called with fileName, sampleRate, status, and textHash
- **THEN** a new episode record is created with the provided text_hash value
