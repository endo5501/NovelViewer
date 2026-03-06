## MODIFIED Requirements

### Requirement: Bookmark list display
The bookmark list panel SHALL display all bookmarks for the currently active novel. Each bookmark SHALL show the file name and line number (if available). When no novel is active (user is at library root), a message SHALL be displayed.

#### Scenario: Display bookmarks with line numbers
- **WHEN** the user is browsing files within a novel folder and switches to the bookmark tab
- **THEN** all bookmarks for that novel SHALL be displayed as a scrollable list showing file names with line numbers (e.g., "chapter01.txt : L42")

#### Scenario: Display bookmark without line number
- **WHEN** a bookmark has no line number (null)
- **THEN** the bookmark SHALL be displayed with the file name only, without line number suffix

#### Scenario: No bookmarks exist for active novel
- **WHEN** the user switches to the bookmark tab and the active novel has no bookmarks
- **THEN** a message SHALL be displayed indicating no bookmarks exist

#### Scenario: No novel is active
- **WHEN** the user is at the library root directory and switches to the bookmark tab
- **THEN** a message SHALL be displayed prompting to select a novel folder

### Requirement: Bookmark keyboard shortcut
The application SHALL support Command+B (macOS) / Control+B (Windows/Linux) keyboard shortcut to toggle the bookmark state of the currently viewed position.

#### Scenario: Add bookmark via keyboard shortcut with line position
- **WHEN** a file is displayed in the text viewer at line 42 and is not bookmarked at that line
- **AND** the user presses Command+B (macOS) or Control+B (Windows/Linux)
- **THEN** a bookmark SHALL be added for the current novel with the current file path and current display line number

#### Scenario: Remove bookmark via keyboard shortcut
- **WHEN** a file is displayed in the text viewer and a bookmark exists at the current display line
- **AND** the user presses Command+B (macOS) or Control+B (Windows/Linux)
- **THEN** the bookmark at the current line SHALL be removed

#### Scenario: Keyboard shortcut with no file selected
- **WHEN** no file is selected in the text viewer
- **AND** the user presses Command+B (macOS) or Control+B (Windows/Linux)
- **THEN** the shortcut SHALL be ignored (no action taken)

### Requirement: Bookmark button in AppBar
The AppBar SHALL display a bookmark toggle button that adds or removes a bookmark at the currently displayed position. The button icon SHALL reflect whether the current display position is bookmarked.

#### Scenario: Bookmark button shows unbookmarked state
- **WHEN** a file is displayed and the current display line is not bookmarked
- **THEN** the AppBar SHALL display a bookmark button with an outline icon (Icons.bookmark_border)

#### Scenario: Bookmark button shows bookmarked state
- **WHEN** a file is displayed and the current display line is bookmarked
- **THEN** the AppBar SHALL display a bookmark button with a filled icon (Icons.bookmark)

#### Scenario: Bookmark button adds bookmark with line number
- **WHEN** the user clicks the bookmark button while viewing line 42 of a non-bookmarked position
- **THEN** a bookmark SHALL be added with the current file path and line number 42

#### Scenario: Bookmark button removes bookmark
- **WHEN** the user clicks the bookmark button while viewing a bookmarked line
- **THEN** the bookmark at that line SHALL be removed

### Requirement: Open file from bookmark with line jump
The user SHALL be able to open a bookmarked file by tapping on it in the bookmark list. The file browser SHALL navigate to the file's directory, select the file, and jump to the bookmarked line.

#### Scenario: Open bookmarked file with line number in horizontal mode
- **WHEN** the user taps on a bookmark with file_path and line_number 42
- **AND** the display mode is horizontal
- **THEN** the file SHALL be opened and the text viewer SHALL scroll to line 42

#### Scenario: Open bookmarked file with line number in vertical mode
- **WHEN** the user taps on a bookmark with file_path and line_number (page number) 3
- **AND** the display mode is vertical
- **THEN** the file SHALL be opened and the text viewer SHALL navigate to page 3

#### Scenario: Open bookmarked file without line number
- **WHEN** the user taps on a bookmark with line_number null
- **THEN** the file SHALL be opened from the beginning (default behavior)

#### Scenario: Open bookmarked file that no longer exists
- **WHEN** the user taps on a bookmark whose file has been deleted from the filesystem
- **THEN** an error message SHALL be displayed indicating the file was not found

## ADDED Requirements

### Requirement: Bookmark indicator in text viewer
The text viewer SHALL display a visual bookmark indicator on lines that have been bookmarked. The indicator SHALL be a bookmark icon displayed at the left margin of the bookmarked line.

#### Scenario: Display bookmark indicator on bookmarked line in horizontal mode
- **WHEN** a file is displayed in horizontal mode and line 42 has a bookmark
- **THEN** a bookmark icon (Icons.bookmark) SHALL be displayed at the left margin of line 42

#### Scenario: Display multiple bookmark indicators
- **WHEN** a file is displayed and lines 10, 42, and 100 have bookmarks
- **THEN** bookmark icons SHALL be displayed at the left margin of all three lines

#### Scenario: No bookmark indicator on non-bookmarked lines
- **WHEN** a file is displayed and line 50 does not have a bookmark
- **THEN** no bookmark icon SHALL be displayed at line 50

#### Scenario: Display bookmark indicator in vertical mode
- **WHEN** a file is displayed in vertical mode and a bookmark exists for a page
- **THEN** a bookmark icon SHALL be displayed at the top of the page to indicate it contains a bookmarked position

#### Scenario: Bookmark indicator updates when bookmark is added
- **WHEN** a bookmark is added at the current line
- **THEN** the bookmark icon SHALL appear immediately at that line

#### Scenario: Bookmark indicator updates when bookmark is removed
- **WHEN** a bookmark is removed from a line
- **THEN** the bookmark icon SHALL disappear immediately from that line
