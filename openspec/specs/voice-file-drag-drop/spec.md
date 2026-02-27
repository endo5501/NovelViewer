## Purpose

TBD - Voice file drag and drop functionality for adding audio files to the voices directory via the TTS settings UI.

## Requirements

### Requirement: Drag and drop voice file addition
The system SHALL accept audio files dropped from the platform's native file manager onto the voice reference selector area in the TTS settings tab. The system SHALL copy dropped files to the `voices` directory. Only files with supported extensions (`.wav`, `.mp3`) SHALL be accepted. After a successful drop, the voice file list SHALL be refreshed automatically.

#### Scenario: Drop a supported audio file onto the selector
- **WHEN** the user drags a `.wav` or `.mp3` file from the file manager and drops it onto the voice reference selector area
- **THEN** the system copies the file to the `voices` directory and refreshes the file list to include the newly added file

#### Scenario: Drop multiple supported audio files
- **WHEN** the user drops multiple `.wav` and `.mp3` files onto the voice reference selector area
- **THEN** the system copies all supported files to the `voices` directory and refreshes the file list

#### Scenario: Drop an unsupported file type
- **WHEN** the user drops a file with an unsupported extension (e.g., `.txt`, `.ogg`) onto the voice reference selector area
- **THEN** the system SHALL reject the file and display an error message indicating that only `.wav` and `.mp3` files are supported

#### Scenario: Drop a file with a name that already exists in voices directory
- **WHEN** the user drops a file whose name already exists in the `voices` directory
- **THEN** the system SHALL display an error message indicating the file already exists and SHALL NOT overwrite the existing file

### Requirement: Drop zone visual feedback
The system SHALL provide visual feedback when a file is being dragged over the voice reference selector area. The drop zone SHALL indicate that file drop is accepted by displaying a highlighted border and a guidance message.

#### Scenario: File dragged over the drop zone
- **WHEN** the user drags a file over the voice reference selector area
- **THEN** the system displays a highlighted border around the area and shows the text "音声ファイルをここにドロップ"

#### Scenario: File dragged away from the drop zone
- **WHEN** the user drags a file away from the voice reference selector area without dropping
- **THEN** the visual feedback (highlighted border and guidance message) is removed and the selector returns to its normal appearance
