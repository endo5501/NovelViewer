## Requirements

### Requirement: File listing
The system SHALL list all text files in the selected directory, displayed as a scrollable list in the left column.

#### Scenario: Directory contains text files
- **WHEN** a directory containing `.txt` files is selected
- **THEN** all `.txt` files are listed in the left column

#### Scenario: Directory is empty
- **WHEN** a directory containing no `.txt` files is selected
- **THEN** the left column displays a message indicating no text files were found

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
The system SHALL display subdirectories in the file list, allowing the user to navigate into them to view their contents.

#### Scenario: Directory contains subdirectories
- **WHEN** a directory contains subdirectories (each representing a novel title)
- **THEN** subdirectories are listed and the user can navigate into them to see their text files

#### Scenario: User navigates back to parent directory
- **WHEN** the user is inside a subdirectory
- **THEN** a navigation option to return to the parent directory is available

### Requirement: Automatic refresh after download
The file browser SHALL automatically refresh its file listing when a download operation completes.

#### Scenario: Download completes
- **WHEN** a download completes
- **THEN** the file listing is automatically refreshed to include the newly downloaded files
