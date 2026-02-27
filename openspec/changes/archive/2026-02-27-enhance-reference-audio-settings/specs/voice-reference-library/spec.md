## ADDED Requirements

### Requirement: Add voice file by copy
The system SHALL provide functionality to copy an audio file from an external path into the `voices` directory. The system SHALL validate that the file has a supported extension (`.wav`, `.mp3`) before copying. The system SHALL reject files whose names already exist in the `voices` directory.

#### Scenario: Copy a supported audio file to voices directory
- **WHEN** `addVoiceFile` is called with a path to a `.wav` or `.mp3` file
- **AND** no file with the same name exists in the `voices` directory
- **THEN** the file is copied to the `voices` directory and the copied file name is returned

#### Scenario: Reject unsupported file extension
- **WHEN** `addVoiceFile` is called with a path to a file with an unsupported extension (e.g., `.txt`, `.ogg`)
- **THEN** the system throws an exception indicating the file type is not supported

#### Scenario: Reject duplicate file name
- **WHEN** `addVoiceFile` is called with a path to a file whose name already exists in the `voices` directory
- **THEN** the system throws an exception indicating a file with that name already exists

#### Scenario: Auto-create voices directory before copy
- **WHEN** `addVoiceFile` is called and the `voices` directory does not exist
- **THEN** the system creates the `voices` directory before copying the file

### Requirement: Rename voice file
The system SHALL provide functionality to rename a voice file within the `voices` directory. The system SHALL validate that the new name does not conflict with an existing file. The file extension SHALL be preserved during rename.

#### Scenario: Rename a voice file with a valid new name
- **WHEN** `renameVoiceFile` is called with an existing file name and a valid new name
- **AND** no file with the new name exists in the `voices` directory
- **THEN** the file is renamed in the `voices` directory

#### Scenario: Reject rename to an existing name
- **WHEN** `renameVoiceFile` is called with a new name that matches an existing file in the `voices` directory
- **THEN** the system throws an exception indicating the target name already exists

#### Scenario: Reject rename of a non-existent file
- **WHEN** `renameVoiceFile` is called with a file name that does not exist in the `voices` directory
- **THEN** the system throws an exception indicating the source file does not exist
