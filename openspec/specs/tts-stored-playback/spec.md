### Requirement: Playback controls for stored audio
The system SHALL display playback controls when completed TTS audio exists for the current episode. Controls SHALL include: a play button, a delete button. During playback, controls SHALL change to: a pause button, a stop button.

#### Scenario: Show play and delete buttons when audio ready
- **WHEN** the user views an episode with completed TTS audio
- **THEN** a play button and a delete button are displayed

#### Scenario: Show pause and stop during playback
- **WHEN** audio is currently playing
- **THEN** a pause button and a stop button are displayed

#### Scenario: Show resume and stop during pause
- **WHEN** audio is currently paused
- **THEN** a play (resume) button and a stop button are displayed

### Requirement: Sequential segment playback from database
The system SHALL play stored audio by retrieving WAV BLOBs from the `tts_segments` table in segment_index order. For each segment, the system SHALL write the WAV BLOB to a temporary file and play it using the audio player. When the current segment finishes, the next segment is loaded and played. Database reads are sufficiently fast (single-digit milliseconds on SSD) that pre-loading is unnecessary.

#### Scenario: Play all segments in order
- **WHEN** playback starts for an episode with 15 segments
- **THEN** segments are played sequentially from segment 0 to segment 14

#### Scenario: Playback reaches end of segments
- **WHEN** the last segment finishes playing
- **THEN** playback stops, the state returns to "stopped", and the highlight is cleared

#### Scenario: Temporary files cleaned up after playback
- **WHEN** playback stops (by user action or end of segments)
- **THEN** temporary WAV files created during playback are deleted

### Requirement: Pause and resume playback
The system SHALL support pausing and resuming audio playback. Pause SHALL stop audio at the current position within a segment. Resume SHALL continue from the paused position.

#### Scenario: Pause during playback
- **WHEN** the user presses the pause button while audio is playing
- **THEN** audio pauses at the current position and the state changes to "paused"

#### Scenario: Resume from paused position
- **WHEN** the user presses the play button while audio is paused
- **THEN** audio resumes from the paused position and the state changes to "playing"

### Requirement: Stop playback
The system SHALL support stopping playback. Stop SHALL halt audio, reset the playback position to the beginning, clear the highlight, and clean up temporary files.

#### Scenario: Stop during playback
- **WHEN** the user presses the stop button while audio is playing
- **THEN** audio stops, playback position resets, highlight is cleared, and temporary files are cleaned up

#### Scenario: Stop during pause
- **WHEN** the user presses the stop button while audio is paused
- **THEN** audio stops, playback position resets, highlight is cleared, and temporary files are cleaned up

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
