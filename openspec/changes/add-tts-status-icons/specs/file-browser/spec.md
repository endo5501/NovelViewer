## MODIFIED Requirements

### Requirement: File listing
The system SHALL list all text files in the selected directory, displayed as a scrollable list in the left column. Each episode file SHALL display a TTS status icon in the trailing position when the episode has TTS data (status `completed` or `partial`).

#### Scenario: Directory contains text files
- **WHEN** a directory containing `.txt` files is selected
- **THEN** all `.txt` files are listed in the left column

#### Scenario: Directory is empty
- **WHEN** a directory containing no `.txt` files is selected
- **THEN** the left column displays a message indicating no text files were found

#### Scenario: Episode with completed TTS shows trailing icon
- **WHEN** a directory contains an episode file with TTS status `completed`
- **THEN** the file's `ListTile` displays a green `check_circle` icon in the trailing position

#### Scenario: Episode with partial TTS shows trailing icon
- **WHEN** a directory contains an episode file with TTS status `partial`
- **THEN** the file's `ListTile` displays an orange `pie_chart` icon in the trailing position

#### Scenario: Episode with no TTS shows no trailing icon
- **WHEN** a directory contains an episode file with no TTS data
- **THEN** the file's `ListTile` does not display a trailing icon

#### Scenario: Trailing icon removed after TTS audio deletion
- **WHEN** a user deletes TTS audio data for an episode and returns to the file browser
- **THEN** the episode's `ListTile` no longer displays a trailing TTS status icon
