## MODIFIED Requirements

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
The system SHALL provide a `TtsAudioRepository` class with methods to: create an episode record (with text_hash), insert segment records (with or without audio_data), update a segment's text (setting audio_data and sample_count to NULL), update a segment's audio_data and sample_count, update a segment's ref_wav_path, update a segment's memo, query episode status by file_name, retrieve all segments for an episode ordered by segment_index, find a segment by text_offset, get the count of stored segments for an episode, get the count of segments with non-NULL audio_data for an episode, delete a single segment by episode_id and segment_index, and delete an episode (cascading to segments).

#### Scenario: Check if episode has audio
- **WHEN** `findEpisodeByFileName("0001_プロローグ.txt")` is called
- **THEN** the episode record is returned if it exists, or null if no audio has been generated

#### Scenario: Retrieve segments for playback
- **WHEN** `getSegments(episodeId)` is called for an episode with 15 segments
- **THEN** all 15 segments are returned ordered by segment_index, each containing audio BLOB data (or NULL if not generated)

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
