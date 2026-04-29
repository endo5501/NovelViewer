## ADDED Requirements

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

## MODIFIED Requirements

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

### Requirement: TTS audio database closure
The system SHALL close the `tts_audio.db` database connection when the Riverpod provider entry holding the database is invalidated or when the owning `ProviderContainer` is disposed (e.g., the user navigates away from the current novel folder, or the application terminates).

#### Scenario: Close database when leaving novel
- **WHEN** the user navigates away from the current novel folder and the provider entry for that folder is invalidated
- **THEN** the `TtsAudioDatabase.close` is invoked via `ref.onDispose` and the underlying connection is released
