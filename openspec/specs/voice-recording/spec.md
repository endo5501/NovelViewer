# Voice Recording

## Purpose

Provide in-app voice recording functionality that allows users to record reference audio directly from their microphone, with real-time feedback and file management.

## Requirements

### Requirement: Microphone permission check
The system SHALL check for microphone access permission before starting a recording. If permission is not granted, the system SHALL request permission from the user. If the user denies permission, the system SHALL display an error message indicating that microphone access is required.

#### Scenario: Permission granted
- **WHEN** the user initiates a recording and microphone permission is already granted
- **THEN** the system proceeds to the recording state without additional prompts

#### Scenario: Permission not yet determined
- **WHEN** the user initiates a recording and microphone permission has not been requested before
- **THEN** the system requests microphone permission from the operating system
- **AND** if the user grants permission, the system proceeds to the recording state

#### Scenario: Permission denied
- **WHEN** the user initiates a recording and microphone permission has been denied
- **THEN** the system displays an error message indicating that microphone access is required for recording

### Requirement: Audio recording start and stop
The system SHALL provide the ability to start and stop audio recording from the device microphone. Recording SHALL capture audio in WAV format (PCM 16-bit, 16kHz, mono). The recording SHALL write to a temporary file during the recording session.

#### Scenario: Start recording
- **WHEN** the user presses the record button in the recording dialog
- **THEN** the system starts capturing audio from the microphone
- **AND** the system writes audio data to a temporary WAV file

#### Scenario: Stop recording
- **WHEN** the user presses the stop button while recording is in progress
- **THEN** the system stops capturing audio
- **AND** the temporary WAV file contains the complete recorded audio

#### Scenario: Recording produces valid WAV file
- **WHEN** a recording session is completed (started and stopped)
- **THEN** the resulting temporary file SHALL be a valid WAV file with PCM 16-bit encoding, 16kHz sample rate, and mono channel

### Requirement: Recording state feedback
The system SHALL display real-time feedback during recording, including the elapsed recording time and the current audio input level (amplitude).

#### Scenario: Display elapsed time
- **WHEN** recording is in progress
- **THEN** the system displays the elapsed recording time in `MM:SS` format, updated every second

#### Scenario: Display audio level
- **WHEN** recording is in progress
- **THEN** the system displays a visual indicator of the current audio input level (amplitude), updated in real-time

### Requirement: Recording dialog UI
The system SHALL present the recording functionality in a dedicated dialog (`VoiceRecordingDialog`) opened from the voice reference selector in the settings screen. The dialog SHALL display a record button, and during recording, a stop button with elapsed time and audio level feedback.

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

### Requirement: Save recorded file with user-specified name
After stopping a recording, the system SHALL prompt the user to enter a file name for the recorded audio. The system SHALL save the file to the `voices/` directory with a `.wav` extension. The system SHALL validate that no file with the same name already exists in the `voices/` directory.

#### Scenario: Save with valid name
- **WHEN** the user enters a file name (e.g., `my-voice`) after stopping a recording
- **AND** no file named `my-voice.wav` exists in the `voices/` directory
- **THEN** the system saves the recorded audio as `my-voice.wav` in the `voices/` directory
- **AND** the dialog closes and returns the saved file name

#### Scenario: Reject duplicate file name
- **WHEN** the user enters a file name that already exists in the `voices/` directory (e.g., `existing-voice.wav`)
- **THEN** the system displays an error indicating the file name already exists
- **AND** the user is prompted to enter a different name

#### Scenario: Cancel save
- **WHEN** the user cancels the file name input after stopping a recording
- **THEN** the temporary recorded file is deleted
- **AND** no file is saved to the `voices/` directory

### Requirement: Temporary file cleanup
The system SHALL delete the temporary recording file when the recording dialog is dismissed without saving, or when the user cancels the save operation.

#### Scenario: Dialog dismissed during recording
- **WHEN** the recording dialog is dismissed while recording is in progress
- **THEN** the system stops the recording and deletes the temporary file

#### Scenario: Dialog dismissed after recording without saving
- **WHEN** the recording dialog is dismissed after a recording is completed but before saving
- **THEN** the system deletes the temporary file

#### Scenario: Cleanup after cancel
- **WHEN** the user cancels the file name input after recording
- **THEN** the temporary file is deleted

### Requirement: Prevent accidental dialog dismissal during recording
The system SHALL prevent accidental dismissal of the recording dialog while recording is in progress. If the user attempts to close the dialog during recording, the system SHALL confirm the action before proceeding.

#### Scenario: Attempt to close during recording
- **WHEN** the user attempts to close the recording dialog while recording is in progress
- **THEN** the system displays a confirmation prompt asking if the user wants to discard the recording

#### Scenario: Confirm discard
- **WHEN** the user confirms discarding the recording
- **THEN** the system stops the recording, deletes the temporary file, and closes the dialog

#### Scenario: Cancel discard
- **WHEN** the user cancels the discard confirmation
- **THEN** the dialog remains open and recording continues

### Requirement: Voice file list refresh after recording
After a recorded file is successfully saved to the `voices/` directory, the system SHALL refresh the voice file list in the settings dialog to include the newly saved file.

#### Scenario: List updated after save
- **WHEN** a recorded file is successfully saved to the `voices/` directory
- **AND** the recording dialog returns to the settings dialog
- **THEN** the voice file dropdown list is refreshed and includes the newly saved file

### Requirement: WAVE_FORMAT_EXTENSIBLE compatibility
The TTS engine's WAV parser SHALL support `WAVE_FORMAT_EXTENSIBLE` (format code 0xFFFE) in addition to standard PCM (format code 1) and IEEE float (format code 3). When the format code is 0xFFFE, the parser SHALL read the actual audio format from the SubFormat GUID in the extended `fmt ` chunk header.

#### Scenario: Load WAVE_FORMAT_EXTENSIBLE PCM file
- **WHEN** the TTS engine loads a WAV file with `WAVE_FORMAT_EXTENSIBLE` format code (0xFFFE)
- **AND** the SubFormat GUID indicates PCM (sub-format code 1)
- **THEN** the engine decodes the audio data as PCM and processes it normally

#### Scenario: Load WAVE_FORMAT_EXTENSIBLE IEEE float file
- **WHEN** the TTS engine loads a WAV file with `WAVE_FORMAT_EXTENSIBLE` format code (0xFFFE)
- **AND** the SubFormat GUID indicates IEEE float (sub-format code 3)
- **THEN** the engine decodes the audio data as IEEE float and processes it normally

#### Scenario: Recorded WAV used as reference audio
- **WHEN** a user records a reference audio via the recording dialog
- **AND** the recorded WAV file uses `WAVE_FORMAT_EXTENSIBLE` header (as produced by macOS)
- **THEN** the TTS engine accepts the file as valid reference audio without error

### Requirement: macOS microphone entitlement
The macOS application SHALL include the `com.apple.security.device.audio-input` entitlement and the `NSMicrophoneUsageDescription` key in `Info.plist` to enable microphone access.

#### Scenario: macOS entitlements configured
- **WHEN** the application is built for macOS
- **THEN** the `DebugProfile.entitlements` and `Release.entitlements` files include `com.apple.security.device.audio-input` set to `true`
- **AND** the `Info.plist` includes `NSMicrophoneUsageDescription` with a description explaining why the application needs microphone access
