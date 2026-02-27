## ADDED Requirements

### Requirement: Voices directory management
The system SHALL manage a `voices` directory at `{LibraryParentDir}/voices/` for storing reference audio files. The system SHALL automatically create the `voices` directory if it does not exist when the directory path is first resolved.

#### Scenario: Resolve voices directory path
- **WHEN** the voices directory path is requested
- **THEN** the system returns `{LibraryParentDir}/voices/` where `LibraryParentDir` is the parent directory of the NovelViewer library path

#### Scenario: Auto-create voices directory
- **WHEN** the voices directory path is resolved and the directory does not exist
- **THEN** the system creates the `voices` directory automatically

#### Scenario: Voices directory already exists
- **WHEN** the voices directory path is resolved and the directory already exists
- **THEN** the system returns the existing path without modification

### Requirement: Voice file enumeration
The system SHALL enumerate audio files in the `voices` directory filtered by supported extensions (`.wav`, `.mp3`). The enumeration SHALL return file names sorted alphabetically (case-insensitive). Only files in the top-level `voices` directory SHALL be listed (no subdirectory recursion).

#### Scenario: List audio files in voices directory
- **WHEN** the voices directory contains files `sample_a.wav`, `narrator.mp3`, `readme.txt`, and `voice_b.wav`
- **THEN** the enumeration returns `["narrator.mp3", "sample_a.wav", "voice_b.wav"]` (sorted, filtered)

#### Scenario: Empty voices directory
- **WHEN** the voices directory contains no supported audio files
- **THEN** the enumeration returns an empty list

#### Scenario: Voices directory does not exist
- **WHEN** the voices directory does not exist at enumeration time
- **THEN** the system creates the directory and returns an empty list

### Requirement: Voice file path resolution
The system SHALL resolve a voice file name to a full absolute path by joining the voices directory path with the file name.

#### Scenario: Resolve file name to full path
- **WHEN** a file name `narrator.mp3` is provided for resolution
- **THEN** the system returns `{LibraryParentDir}/voices/narrator.mp3`

### Requirement: Open voices directory in file manager
The system SHALL provide functionality to open the `voices` directory in the platform's native file manager (Finder on macOS, Explorer on Windows).

#### Scenario: Open voices directory on macOS
- **WHEN** the user requests to open the voices directory on macOS
- **THEN** the system opens the `voices` directory in Finder

#### Scenario: Open voices directory on Windows
- **WHEN** the user requests to open the voices directory on Windows
- **THEN** the system opens the `voices` directory in Explorer

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
