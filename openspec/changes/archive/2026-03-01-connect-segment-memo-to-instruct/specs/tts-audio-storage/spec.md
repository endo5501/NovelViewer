## MODIFIED Requirements

### Requirement: TTS audio repository CRUD operations
The system SHALL provide a `TtsAudioRepository` class with methods to: create an episode record (with text_hash), insert segment records (with or without audio_data, with optional memo), update a segment's text (setting audio_data and sample_count to NULL), update a segment's audio_data and sample_count, update a segment's ref_wav_path, update a segment's memo, query episode status by file_name, retrieve all segments for an episode ordered by segment_index, find a segment by text_offset, get the count of stored segments for an episode, get the count of segments with non-NULL audio_data for an episode, delete a single segment by episode_id and segment_index, delete an episode (cascading to segments), and retrieve all episode statuses as a map of file_name to TtsEpisodeStatus.

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

#### Scenario: Insert segment with memo
- **WHEN** `insertSegment()` is called with memo="怒りの口調で"
- **THEN** a segment record is created with the memo value stored in the memo column

#### Scenario: Insert segment without memo
- **WHEN** `insertSegment()` is called without a memo parameter
- **THEN** a segment record is created with memo=NULL

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
