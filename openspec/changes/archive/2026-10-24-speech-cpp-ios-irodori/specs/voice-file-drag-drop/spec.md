## MODIFIED Requirements

### Requirement: Drag and drop voice file addition
Where the platform supports dropping voice files (`platform-capabilities`), the system SHALL accept audio files dropped from the platform's native file manager onto the voice reference selector area in the TTS settings tab. Where it does not, as on iOS, the selector SHALL NOT register a drop target. The system SHALL copy dropped files to the `voices` directory. Only files with supported extensions (`.wav`, `.mp3`) SHALL be accepted. After a successful drop, the voice file list SHALL be refreshed automatically.

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

#### Scenario: No drop target on iOS
- **WHEN** the voice reference section is shown on iOS
- **THEN** the selector registers no drop target, and the section works without the drag-and-drop plugin
