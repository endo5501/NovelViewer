## ADDED Requirements

### Requirement: Left column tab switching
The left column SHALL display a tab bar with two tabs: "ファイル" (file browser) and "ブックマーク" (bookmark list). The user SHALL be able to switch between tabs by tapping on them.

#### Scenario: Application launches with file browser tab active
- **WHEN** the application launches
- **THEN** the left column SHALL display a tab bar at the top with "ファイル" tab selected by default
- **AND** the file browser panel SHALL be displayed below the tab bar

#### Scenario: User switches to bookmark tab
- **WHEN** the user taps the "ブックマーク" tab
- **THEN** the bookmark list panel SHALL be displayed below the tab bar
- **AND** the "ブックマーク" tab SHALL be visually indicated as active

#### Scenario: User switches back to file browser tab
- **WHEN** the user taps the "ファイル" tab while viewing the bookmark list
- **THEN** the file browser panel SHALL be displayed below the tab bar
- **AND** the file browser state (current directory, selected file) SHALL be preserved

### Requirement: Bookmark list display
The bookmark list panel SHALL display all bookmarks for the currently active novel. Each bookmark SHALL show the file name. When no novel is active (user is at library root), a message SHALL be displayed.

#### Scenario: Display bookmarks for active novel
- **WHEN** the user is browsing files within a novel folder and switches to the bookmark tab
- **THEN** all bookmarks for that novel SHALL be displayed as a scrollable list showing file names

#### Scenario: No bookmarks exist for active novel
- **WHEN** the user switches to the bookmark tab and the active novel has no bookmarks
- **THEN** a message "ブックマークがありません" SHALL be displayed

#### Scenario: No novel is active
- **WHEN** the user is at the library root directory and switches to the bookmark tab
- **THEN** a message "作品フォルダを選択してください" SHALL be displayed

### Requirement: Bookmark keyboard shortcut
The application SHALL support Command+B (macOS) / Control+B (Windows/Linux) keyboard shortcut to toggle the bookmark state of the currently selected file.

#### Scenario: Add bookmark via keyboard shortcut
- **WHEN** a file is selected in the text viewer and is not bookmarked
- **AND** the user presses Command+B (macOS) or Control+B (Windows/Linux)
- **THEN** the file SHALL be added to bookmarks for the current novel

#### Scenario: Remove bookmark via keyboard shortcut
- **WHEN** a file is selected in the text viewer and is already bookmarked
- **AND** the user presses Command+B (macOS) or Control+B (Windows/Linux)
- **THEN** the bookmark for the file SHALL be removed

#### Scenario: Keyboard shortcut with no file selected
- **WHEN** no file is selected in the text viewer
- **AND** the user presses Command+B (macOS) or Control+B (Windows/Linux)
- **THEN** the shortcut SHALL be ignored (no action taken)

### Requirement: Bookmark button in AppBar
The AppBar SHALL display a bookmark toggle button that adds or removes the currently selected file from bookmarks. The button icon SHALL reflect the bookmark state of the current file.

#### Scenario: Bookmark button shows unbookmarked state
- **WHEN** a file is selected and it is not bookmarked
- **THEN** the AppBar SHALL display a bookmark button with an outline icon (Icons.bookmark_border)

#### Scenario: Bookmark button shows bookmarked state
- **WHEN** a file is selected and it is already bookmarked
- **THEN** the AppBar SHALL display a bookmark button with a filled icon (Icons.bookmark)

#### Scenario: Bookmark button adds bookmark
- **WHEN** the user clicks the bookmark button while a non-bookmarked file is selected
- **THEN** the file SHALL be added to bookmarks and the icon SHALL change to filled (Icons.bookmark)

#### Scenario: Bookmark button removes bookmark
- **WHEN** the user clicks the bookmark button while a bookmarked file is selected
- **THEN** the bookmark SHALL be removed and the icon SHALL change to outline (Icons.bookmark_border)

#### Scenario: Bookmark button disabled when no file selected
- **WHEN** no file is selected
- **THEN** the bookmark button SHALL be disabled (not clickable)

#### Scenario: Bookmark button disabled at library root
- **WHEN** the user is at the library root directory (no novel context)
- **THEN** the bookmark button SHALL be disabled (not clickable)

### Requirement: Delete bookmark from list
The user SHALL be able to delete a bookmark by right-clicking on it in the bookmark list and selecting "削除" from the context menu.

#### Scenario: Right-click shows context menu
- **WHEN** the user right-clicks on a bookmark item in the bookmark list
- **THEN** a context menu SHALL appear with a "削除" option

#### Scenario: Delete bookmark via context menu
- **WHEN** the user selects "削除" from the bookmark context menu
- **THEN** the bookmark SHALL be removed from the database
- **AND** the bookmark list SHALL refresh to reflect the removal

### Requirement: Open file from bookmark
The user SHALL be able to open a bookmarked file by tapping on it in the bookmark list. The file browser SHALL navigate to the file's directory and select the file.

#### Scenario: Open bookmarked file
- **WHEN** the user taps on a bookmark in the bookmark list
- **THEN** the file browser SHALL navigate to the directory containing the bookmarked file
- **AND** the file SHALL be selected and displayed in the text viewer

#### Scenario: Open bookmarked file that no longer exists
- **WHEN** the user taps on a bookmark whose file has been deleted from the filesystem
- **THEN** an error message SHALL be displayed indicating the file was not found
