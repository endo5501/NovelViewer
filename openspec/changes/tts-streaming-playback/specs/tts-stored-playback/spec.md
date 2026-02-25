## MODIFIED Requirements

### Requirement: Playback controls for stored audio
The system SHALL display playback controls when TTS audio exists for the current episode (status "partial" or "completed"). Controls SHALL include: a play button, a delete button. During playback, controls SHALL change to: a pause button, a stop button. During the waiting state (playback caught up to generation), a loading indicator SHALL be displayed alongside the pause and stop buttons.

#### Scenario: Show play and delete buttons when audio ready
- **WHEN** the user views an episode with TTS audio (status "partial" or "completed")
- **THEN** a play button and a delete button are displayed

#### Scenario: Show pause and stop during playback
- **WHEN** audio is currently playing
- **THEN** a pause button and a stop button are displayed

#### Scenario: Show resume and stop during pause
- **WHEN** audio is currently paused
- **THEN** a play (resume) button and a stop button are displayed

#### Scenario: Show loading indicator during waiting state
- **WHEN** playback has caught up to generation and is waiting for the next segment
- **THEN** a loading indicator is displayed alongside the pause and stop buttons

### Requirement: Sequential segment playback from database
The system SHALL play stored audio by retrieving WAV BLOBs from the `tts_segments` table in segment_index order. For each segment, the system SHALL write the WAV BLOB to a temporary file and play it using the audio player. When the current segment finishes, the next segment is loaded and played. If the next segment has not yet been generated, the system SHALL wait for generation to complete before proceeding. Playback SHALL work with both "partial" and "completed" episodes.

#### Scenario: Play all segments in order
- **WHEN** playback starts for a completed episode with 15 segments
- **THEN** segments are played sequentially from segment 0 to segment 14

#### Scenario: Play partial episode and continue with generation
- **WHEN** playback starts for a partial episode with 5 of 15 segments stored
- **THEN** segments 0-4 are played from the database, then playback waits for and plays segments 5-14 as they are generated

#### Scenario: Playback reaches end of segments
- **WHEN** the last segment finishes playing
- **THEN** playback stops, the state returns to "stopped", and the highlight is cleared

#### Scenario: Temporary files cleaned up after playback
- **WHEN** playback stops (by user action or end of segments)
- **THEN** temporary WAV files created during playback are deleted

## ADDED Requirements

### Requirement: Waiting state in playback state enum
The `TtsPlaybackState` enum SHALL include a `waiting` value in addition to `stopped`, `playing`, and `paused`. The `waiting` state indicates that playback has caught up to generation and is waiting for the next segment to become available.

#### Scenario: Playback state transitions to waiting
- **WHEN** the current segment finishes playing and the next segment is not yet in the database
- **THEN** `TtsPlaybackState` transitions from `playing` to `waiting`

#### Scenario: Playback state transitions from waiting to playing
- **WHEN** the next segment becomes available in the database while in `waiting` state
- **THEN** `TtsPlaybackState` transitions from `waiting` to `playing`
