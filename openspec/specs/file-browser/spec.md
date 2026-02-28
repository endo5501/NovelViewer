## Requirements

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

### Requirement: Numeric prefix sorting
Text files SHALL be sorted by their numeric prefix in ascending order. Files without numeric prefixes SHALL be sorted alphabetically after numbered files.

#### Scenario: Files with numeric prefixes are sorted
- **WHEN** a directory contains files named `001_chapter1.txt`, `010_chapter10.txt`, `002_chapter2.txt`
- **THEN** they are displayed in order: `001_chapter1.txt`, `002_chapter2.txt`, `010_chapter10.txt`

#### Scenario: Files without numeric prefixes are sorted after numbered files
- **WHEN** a directory contains `001_chapter1.txt`, `readme.txt`, `002_chapter2.txt`
- **THEN** they are displayed in order: `001_chapter1.txt`, `002_chapter2.txt`, `readme.txt`

### Requirement: File selection
The user SHALL be able to select a file from the list by tapping on it, and the selected file SHALL be visually highlighted.

#### Scenario: User selects a file
- **WHEN** the user taps on a file in the list
- **THEN** the file is highlighted and its content is displayed in the center column

#### Scenario: User selects a different file
- **WHEN** the user taps on a different file while one is already selected
- **THEN** the new file is highlighted, the previous highlight is removed, and the center column updates to show the new file's content

### Requirement: Subdirectory navigation
The system SHALL display subdirectories in the file list, allowing the user to navigate into them to view their contents. At the library root level, subdirectories that are registered in the metadata database SHALL be displayed with their novel title instead of the folder name. Parent directory navigation SHALL work correctly on all platforms regardless of the path separator used by the operating system.

#### Scenario: Library root shows registered novels with titles
- **WHEN** the user is at the library root directory and subdirectories exist that are registered in the metadata database
- **THEN** those subdirectories are displayed with the novel title from the database instead of the ID-based folder name

#### Scenario: Library root shows unregistered folders with folder name
- **WHEN** the user is at the library root directory and subdirectories exist that are NOT registered in the metadata database (legacy title-based folders)
- **THEN** those subdirectories are displayed with their folder name as-is

#### Scenario: User navigates into a registered novel folder
- **WHEN** the user selects a novel displayed with its database title
- **THEN** the file browser navigates into the corresponding ID-based folder and displays its text files

#### Scenario: User navigates back to parent directory
- **WHEN** the user is inside a subdirectory
- **THEN** a navigation option to return to the parent directory is available
- **AND** the navigation SHALL use platform-aware path resolution to determine the parent directory

#### Scenario: User navigates back to parent directory on Windows
- **WHEN** the user is inside a subdirectory with a Windows-style path (e.g., `C:\Users\name\novels\book1`)
- **THEN** the parent directory SHALL be correctly resolved (e.g., `C:\Users\name\novels`)

#### Scenario: User is at root directory
- **WHEN** the user is at a root directory (e.g., `/` on Unix or `C:\` on Windows)
- **THEN** the parent navigation SHALL NOT navigate further up

### Requirement: Automatic refresh after download
The file browser SHALL automatically refresh its file listing when a download operation completes.

#### Scenario: Download completes
- **WHEN** a download completes
- **THEN** the file listing is automatically refreshed to include the newly downloaded files
