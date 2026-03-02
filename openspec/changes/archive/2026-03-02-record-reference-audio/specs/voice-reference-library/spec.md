## ADDED Requirements

### Requirement: Save voice file by move
The system SHALL provide functionality to move an audio file from a source path into the `voices/` directory. Unlike the copy operation (`addVoiceFile`), this operation SHALL move (rename) the source file to the destination, avoiding unnecessary duplication. The system SHALL validate that the file has a supported extension (`.wav`, `.mp3`) and that no file with the same name already exists in the `voices/` directory.

#### Scenario: Move a recorded audio file to voices directory
- **WHEN** `moveVoiceFile` is called with a source path to a `.wav` file and a target file name
- **AND** no file with the target name exists in the `voices/` directory
- **THEN** the source file is moved to the `voices/` directory with the target file name
- **AND** the source file no longer exists at the original location

#### Scenario: Reject unsupported file extension on move
- **WHEN** `moveVoiceFile` is called with a target file name that has an unsupported extension (e.g., `.txt`, `.ogg`)
- **THEN** the system throws an exception indicating the file type is not supported

#### Scenario: Reject duplicate file name on move
- **WHEN** `moveVoiceFile` is called with a target file name that already exists in the `voices/` directory
- **THEN** the system throws an exception indicating a file with that name already exists

#### Scenario: Auto-create voices directory before move
- **WHEN** `moveVoiceFile` is called and the `voices/` directory does not exist
- **THEN** the system creates the `voices/` directory before moving the file
