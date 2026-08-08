## MODIFIED Requirements

### Requirement: TTS segments table schema
The `tts_segments` table SHALL store per-sentence audio data with the following columns: `id` (INTEGER PRIMARY KEY AUTOINCREMENT), `episode_id` (INTEGER NOT NULL — foreign key to tts_episodes), `segment_index` (INTEGER NOT NULL — 0-based sentence order), `text` (TEXT NOT NULL — the sentence text, may be edited by user for pronunciation correction), `text_offset` (INTEGER NOT NULL — position in original text), `text_length` (INTEGER NOT NULL — length in original text), `audio_data` (BLOB — WAV file bytes with header, NULL when segment has no generated audio), `sample_count` (INTEGER — number of audio samples, NULL when segment has no generated audio), `ref_wav_path` (TEXT — voice cloning reference for this segment, nullable), `memo` (TEXT — user memo for future control instruction support, nullable), `skip` (INTEGER NOT NULL DEFAULT 0 — 1 when the segment is excluded from synthesis, playback, and export; 0 otherwise), `created_at` (TEXT NOT NULL). A unique index SHALL exist on `(episode_id, segment_index)`. A foreign key constraint on `episode_id` SHALL reference `tts_episodes(id)` with CASCADE delete.

A segment with `skip = 1` MAY still hold non-NULL `audio_data`: marking a segment as skipped SHALL NOT delete its stored audio, so that un-skipping restores playback without regeneration.

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

#### Scenario: Migrate existing database to version 4
- **WHEN** an existing `tts_audio.db` database at version 3 is opened
- **THEN** the `skip` column is added to `tts_segments` via `ALTER TABLE ... ADD COLUMN skip INTEGER NOT NULL DEFAULT 0`, all existing data is preserved, and every existing segment reads `skip = 0`

#### Scenario: Newly inserted segments default to not skipped
- **WHEN** `insertSegment()` is called without an explicit skip value
- **THEN** the created record has `skip = 0`

#### Scenario: Skipped segment retains its audio
- **WHEN** a segment with non-NULL `audio_data` is marked with `skip = 1`
- **THEN** the `audio_data` and `sample_count` columns are left unchanged

### Requirement: TTS audio repository CRUD operations
The system SHALL provide a `TtsAudioRepository` class with methods to: create an episode record (with text_hash), insert segment records (with or without audio_data, and with an optional skip flag defaulting to not-skipped), update a segment's text (setting audio_data and sample_count to NULL), update a segment's audio_data and sample_count, update a segment's ref_wav_path, update a segment's memo, update a segment's skip flag, query episode status by file_name, retrieve all segments for an episode ordered by segment_index, get the count of stored segments for an episode, get the count of segments that are considered satisfied — those with non-NULL audio_data **or** `skip = 1` — for an episode, delete a single segment by episode_id and segment_index, delete an episode (cascading to segments), and retrieve all episode statuses as a map of file_name to TtsEpisodeStatus. Updating a segment's skip flag SHALL NOT modify its audio_data or sample_count. The repository SHALL NOT provide a text-offset-based segment lookup: resolving a playback start position is the responsibility of the streaming controller, which resolves it against the freshly segmented text rather than against the sparse set of stored rows. All read methods that return row data SHALL return typed DTO instances (`TtsEpisode`, `TtsSegment`) or `null`/empty collections; raw `Map<String, Object?>` SHALL NOT be returned across the repository boundary.

#### Scenario: Check if episode has audio
- **WHEN** `findEpisodeByFileName("0001_プロローグ.txt")` is called
- **THEN** a `TtsEpisode` instance is returned if the episode exists, or `null` if no audio has been generated

#### Scenario: Retrieve segments for playback
- **WHEN** `getSegments(episodeId)` is called for an episode with 15 segments
- **THEN** a `List<TtsSegment>` of length 15 is returned ordered by segment_index, each carrying typed `audioData` (or `null` if not generated)

#### Scenario: No text-offset lookup is exposed
- **WHEN** the public surface of `TtsAudioRepository` is inspected
- **THEN** no method resolves a segment from a text offset; the start position is computed by the streaming controller from the segment list

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

#### Scenario: Update segment skip flag
- **WHEN** `updateSegmentSkip(episodeId, segmentIndex, true)` is called
- **THEN** the segment's skip column is set to 1

#### Scenario: Updating the skip flag preserves stored audio
- **WHEN** `updateSegmentSkip(episodeId, segmentIndex, true)` is called for a segment holding audio_data
- **THEN** the segment's audio_data and sample_count are unchanged

#### Scenario: Insert a segment already marked as skipped
- **WHEN** `insertSegment()` is called with skip=true for a segment whose synthesis input was blank
- **THEN** a segment record is created with `skip = 1`, audio_data=NULL, and sample_count=NULL

#### Scenario: Delete single segment
- **WHEN** `deleteSegment(episodeId, segmentIndex)` is called
- **THEN** only the specified segment record is deleted

#### Scenario: Get count of generated segments
- **WHEN** `getGeneratedSegmentCount(episodeId)` is called for an episode with 10 segments total, 7 having audio_data and no skipped segments
- **THEN** the count 7 is returned

#### Scenario: Skipped segments count as satisfied
- **WHEN** `getGeneratedSegmentCount(episodeId)` is called for an episode with 10 segments total, 7 having audio_data and 3 having `skip = 1` with no audio_data
- **THEN** the count 10 is returned, so the episode can reach "completed"

#### Scenario: A skipped segment holding audio is counted once
- **WHEN** `getGeneratedSegmentCount(episodeId)` is called for an episode where one segment has both audio_data and `skip = 1`
- **THEN** that segment contributes exactly 1 to the count

#### Scenario: Get all episode statuses
- **WHEN** `getAllEpisodeStatuses()` is called on a repository with episodes in various states
- **THEN** a `Map<String, TtsEpisodeStatus>` is returned mapping each episode's file_name to its status

### Requirement: TTS audio data transfer objects
The system SHALL expose typed data transfer objects for `tts_episodes` and `tts_segments` rows. The `TtsEpisode` class SHALL have typed fields for `id` (int), `fileName` (String), `sampleRate` (int), `status` (TtsEpisodeStatus enum), `refWavPath` (String?), `textHash` (String?), `createdAt` (DateTime), and `updatedAt` (DateTime). The `TtsSegment` class SHALL have typed fields for `id` (int), `episodeId` (int), `segmentIndex` (int), `text` (String), `textOffset` (int), `textLength` (int), `audioData` (Uint8List?), `sampleCount` (int?), `refWavPath` (String?), `memo` (String?), `skip` (bool), and `createdAt` (DateTime). Both classes SHALL provide a `fromRow(Map<String, Object?>)` factory that asserts column types and throws on unexpected schema.

#### Scenario: Build TtsEpisode from a complete row
- **WHEN** `TtsEpisode.fromRow` is called with a `Map<String, Object?>` containing all expected columns with valid types
- **THEN** a `TtsEpisode` instance is returned with all fields populated and the status string mapped to the corresponding `TtsEpisodeStatus` enum value

#### Scenario: TtsEpisode parsing rejects unexpected status value
- **WHEN** `TtsEpisode.fromRow` is called with a row whose `status` is not one of `"generating"`, `"partial"`, `"completed"`
- **THEN** a `FormatException` (or equivalent) is thrown so the inconsistency is not silently propagated

#### Scenario: Build TtsSegment with NULL audio
- **WHEN** `TtsSegment.fromRow` is called with a row whose `audio_data` and `sample_count` are NULL
- **THEN** the resulting `TtsSegment` has `audioData == null` and `sampleCount == null`

#### Scenario: Build TtsSegment from a skipped row
- **WHEN** `TtsSegment.fromRow` is called with a row whose `skip` column is 1
- **THEN** the resulting `TtsSegment` has `skip == true`

#### Scenario: Build TtsSegment from a non-skipped row
- **WHEN** `TtsSegment.fromRow` is called with a row whose `skip` column is 0
- **THEN** the resulting `TtsSegment` has `skip == false`
