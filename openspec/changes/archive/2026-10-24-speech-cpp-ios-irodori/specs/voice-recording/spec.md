## MODIFIED Requirements

### Requirement: Recording dialog UI
The system SHALL present the recording functionality in a dedicated dialog (`VoiceRecordingDialog`) opened from the voice reference selector in the settings screen. The dialog SHALL display a record button, and during recording, a stop button with elapsed time and audio level feedback.

The button that opens the dialog SHALL be presented only where the platform supports voice recording (`platform-capabilities`). On iOS it SHALL NOT be presented, so no path reaches the microphone there.

#### Scenario: Open recording dialog
- **WHEN** the user presses the recording button in the voice reference selector section of the settings dialog
- **THEN** the system opens the `VoiceRecordingDialog`

#### Scenario: Recording dialog initial state
- **WHEN** the recording dialog is opened
- **THEN** the dialog displays a record (start) button
- **AND** no recording is in progress

#### Scenario: Recording dialog during recording
- **WHEN** recording is in progress
- **THEN** the dialog displays a stop button, elapsed time, and audio level indicator
- **AND** the record button is replaced by the stop button

#### Scenario: No recording button on iOS
- **WHEN** the voice reference section is shown on iOS
- **THEN** no button that opens the recording dialog is presented
