## Requirements

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

### Requirement: Waiting state in playback state enum
The `TtsPlaybackState` enum SHALL include a `waiting` value in addition to `stopped`, `playing`, and `paused`. The `waiting` state indicates that playback has caught up to generation and is waiting for the next segment to become available.

#### Scenario: Playback state transitions to waiting
- **WHEN** the current segment finishes playing and the next segment is not yet in the database
- **THEN** `TtsPlaybackState` transitions from `playing` to `waiting`

#### Scenario: Playback state transitions from waiting to playing
- **WHEN** the next segment becomes available in the database while in `waiting` state
- **THEN** `TtsPlaybackState` transitions from `waiting` to `playing`

### Requirement: Pause and resume playback
The system SHALL support pausing and resuming audio playback. Pause SHALL stop audio at the current position within a segment. Resume SHALL continue from the paused position.

#### Scenario: Pause during playback
- **WHEN** the user presses the pause button while audio is playing
- **THEN** audio pauses at the current position and the state changes to "paused"

#### Scenario: Resume from paused position
- **WHEN** the user presses the play button while audio is paused
- **THEN** audio resumes from the paused position and the state changes to "playing"

### Requirement: Stop playback
The system SHALL support stopping playback. Stop SHALL halt audio, reset the playback position to the beginning, clear the highlight, and clean up temporary files. Temporary file cleanup SHALL complete before the playback state transitions to "stopped". Cleanup SHALL be resilient to files that have already been deleted by external processes.

#### Scenario: Stop during playback
- **WHEN** the user presses the stop button while audio is playing
- **THEN** audio stops, playback position resets, highlight is cleared, and temporary files are cleaned up

#### Scenario: Stop during pause
- **WHEN** the user presses the stop button while audio is paused
- **THEN** audio stops, playback position resets, highlight is cleared, and temporary files are cleaned up

#### Scenario: Cleanup completes before state transition
- **WHEN** playback stops (by user action or end of segments)
- **THEN** temporary file cleanup completes before `TtsPlaybackState` transitions to `stopped`

#### Scenario: Cleanup handles already-deleted files
- **WHEN** playback stops and some temporary files have already been deleted by external processes
- **THEN** cleanup completes without error, remaining files are deleted

### Requirement: Text position-based playback start
The system SHALL support starting playback from a specific text position. When text is selected, playback SHALL start from the segment containing the selection start offset. The segment SHALL be identified by querying the database for the segment with the largest `text_offset` <= the selection offset.

#### Scenario: Start from selected text position
- **WHEN** the user has selected text starting at offset 19 and presses play
- **THEN** the system queries for the segment with text_offset <= 19, and playback begins from that segment

#### Scenario: Start from beginning when no selection
- **WHEN** no text is selected and the user presses play
- **THEN** playback starts from segment 0

### Requirement: Text highlight during stored playback
The system SHALL highlight the currently playing sentence during playback using the existing TTS highlight mechanism. The highlight range SHALL be set based on the segment's `text_offset` and `text_length` stored in the database.

#### Scenario: Highlight updates per segment
- **WHEN** segment N starts playing (text_offset=8, text_length=11)
- **THEN** the TTS highlight range is set to TextRange(start: 8, end: 19)

#### Scenario: Highlight cleared on stop
- **WHEN** playback is stopped
- **THEN** the TTS highlight range is cleared (set to null)

### Requirement: Auto page turn during stored playback
The system SHALL automatically navigate to the page containing the currently highlighted text during playback, reusing the existing auto page turn mechanism.

#### Scenario: Auto page turn when segment is on next page
- **WHEN** the current segment's text is on a different page than the current display
- **THEN** the viewer navigates to the page containing the highlighted text

### Requirement: Delete stored audio
The system SHALL provide a delete button to remove all stored TTS audio for the current episode. Deletion SHALL remove the episode record and all segments from the database.

#### Scenario: Delete audio for episode
- **WHEN** the user presses the delete button for an episode with stored audio
- **THEN** the episode record and all segments are deleted, and the UI returns to showing the "読み上げ音声生成" button

### Requirement: Playback stops on page navigation
The system SHALL stop playback when the user manually navigates to a different episode. Navigation actions include selecting a different file in the file browser.

#### Scenario: Stop playback on episode change
- **WHEN** the user selects a different episode while audio is playing
- **THEN** playback stops, highlight is cleared, and temporary files are cleaned up
