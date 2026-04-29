## MODIFIED Requirements

### Requirement: Sequential segment playback from database
The system SHALL play stored audio by retrieving WAV BLOBs from the `tts_segments` table in segment_index order. For each segment, the system SHALL write the WAV BLOB to a temporary file and delegate playback (including state transitions, drain handling, and `pause`-not-`stop` semantics) to a shared `SegmentPlayer`. When the current segment finishes, the next segment is loaded and played. If the next segment has not yet been generated, the system SHALL wait for generation to complete before proceeding. Playback SHALL work with both "partial" and "completed" episodes.

#### Scenario: Play all segments in order
- **WHEN** playback starts for a completed episode with 15 segments
- **THEN** segments are played sequentially from segment 0 to segment 14 via the `SegmentPlayer`

#### Scenario: Play partial episode and continue with generation
- **WHEN** playback starts for a partial episode with 5 of 15 segments stored
- **THEN** segments 0-4 are played from the database, then playback waits for and plays segments 5-14 as they are generated

#### Scenario: Playback reaches end of segments
- **WHEN** the last segment finishes playing (after the buffer drain delay handled by the `SegmentPlayer`)
- **THEN** playback stops, the state returns to "stopped", and the highlight is cleared

#### Scenario: Temporary files cleaned up after playback
- **WHEN** playback stops (by user action or end of segments)
- **THEN** temporary WAV files created during playback are deleted

### Requirement: Audio buffer drain before stop on last segment
The buffer drain handling on the last segment SHALL be implemented inside the shared `SegmentPlayer`, not duplicated in `TtsStoredPlayerController`. The wait duration SHALL be configurable via the `SegmentPlayer.bufferDrainDelay` parameter, with a default of 500ms. The `TtsStoredPlayerController` constructor SHALL continue to accept a `bufferDrainDelay` parameter that propagates to its underlying `SegmentPlayer`, preserving existing test fixtures (`bufferDrainDelay: Duration.zero`). If the user stops playback during the buffer drain delay, the delay SHALL be skipped and stop SHALL proceed immediately.

#### Scenario: Last segment waits for buffer drain before stop
- **WHEN** the last segment finishes playback (completed state is received)
- **THEN** the `SegmentPlayer` waits for the configured buffer drain delay before calling its internal stop/pause sequence, ensuring the audio output device finishes playing all buffered samples

#### Scenario: Buffer drain delay is zero in tests
- **WHEN** `TtsStoredPlayerController` is constructed with `bufferDrainDelay: Duration.zero`
- **THEN** the underlying `SegmentPlayer` is configured with `Duration.zero`, allowing tests to complete quickly

#### Scenario: Buffer drain skipped on user stop
- **WHEN** the user stops playback while the buffer drain delay is pending after the last segment
- **THEN** the `SegmentPlayer.stop()` skips the delay and stop proceeds immediately

#### Scenario: Intermediate segments play without drain delay
- **WHEN** an intermediate segment finishes playback and the next segment is ready
- **THEN** the `SegmentPlayer` proceeds to load the next segment after the configured drain delay (which is 500ms by default and `Duration.zero` in tests)
