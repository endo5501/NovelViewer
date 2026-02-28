## MODIFIED Requirements

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
