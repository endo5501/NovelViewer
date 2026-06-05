## Purpose

Browse the local library directory, list episode files for the active novel, and surface per-file TTS status badges.
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
The user SHALL be able to select a file from the list by tapping on it, and the selected file SHALL be visually highlighted with a high-contrast indicator suitable for both light and dark themes. The selected `ListTile` SHALL display:

- a background fill using `Theme.of(context).colorScheme.secondaryContainer`,
- a 4-pixel wide accent border on the leading (left) edge using `Theme.of(context).colorScheme.primary`,
- the title text rendered with `FontWeight.w600` (semibold).

These three visual treatments combine background tint, an edge accent, and weight emphasis so that the selected row remains identifiable independently of color perception or background contrast. Non-selected rows SHALL retain the default `ListTile` appearance.

#### Scenario: User selects a file
- **WHEN** the user taps on a file in the list
- **THEN** the file is highlighted with the secondaryContainer background fill, primary-color leading accent bar, and semibold title text

#### Scenario: User selects a different file
- **WHEN** the user taps on a different file while one is already selected
- **THEN** the new file receives the full highlight treatment, the previous highlight is removed, and the center column updates to show the new file's content

#### Scenario: Highlight remains visible in dark mode
- **WHEN** the application theme is dark mode and a file is selected
- **THEN** the secondaryContainer background, primary leading accent bar, and semibold title remain clearly distinguishable from non-selected rows

### Requirement: Auto-scroll to keep the selected file visible
The file list SHALL automatically scroll so that the currently selected file's `ListTile` is visible within the viewport whenever the selection changes to a file that is currently off-screen. The scroll SHALL be animated and SHALL position the selected row near the vertical center of the list (`alignment ≈ 0.5`). Auto-scroll SHALL only fire on selection changes (i.e., when `selectedFileProvider`'s value transitions to a new file path); it SHALL NOT fire on unrelated rebuilds, on directory changes that already reset the list, or when the same file is re-selected.

If the selected file is already visible within the viewport, the auto-scroll MAY be skipped or MAY perform a no-op `ensureVisible` call — the visible-row position MUST NOT change in a way that the user perceives as an unwanted jump.

#### Scenario: Selecting an off-screen file scrolls it into view
- **WHEN** the file list contains 200 files and the user selects file #150 while the viewport is showing files #1–#20
- **THEN** the list scrolls so that file #150's `ListTile` becomes visible near the center of the viewport

#### Scenario: Selecting a file already in view does not jump
- **WHEN** the file list viewport is currently showing files #45–#65 and the user selects file #50
- **THEN** the viewport does not perform a perceivable jump; file #50 is highlighted in place

#### Scenario: Re-selecting the same file does not trigger scroll
- **WHEN** file #50 is currently selected and the user taps it again
- **THEN** the file list does not perform an animated scroll

#### Scenario: Manual scrolling is not interrupted by unrelated rebuilds
- **WHEN** the user manually scrolls the file list to inspect a different region while their selected file remains unchanged
- **THEN** the file list does not auto-scroll back to the selected file due to unrelated provider rebuilds (e.g., TTS status updates, theme changes)

#### Scenario: External selection change scrolls the list
- **WHEN** the selection is changed by an action other than tapping the list (e.g., next-episode navigation from the text viewer), and the new file is currently off-screen
- **THEN** the file list scrolls so that the newly selected file's `ListTile` becomes visible

### Requirement: Subdirectory navigation
The system SHALL display subdirectories in the file list, allowing the user to navigate into them to view their contents. At any depth within the library, subdirectories whose folder name is registered in the metadata database (i.e. matches a `folder_name`) SHALL be displayed with their novel title instead of the folder name, and SHALL expose a novel context menu on right-click. Parent directory navigation SHALL work correctly on all platforms regardless of the path separator used by the operating system, and SHALL NOT navigate above the library root directory. At any depth, right-clicking a registered novel folder SHALL display a context menu with "更新", "タイトル変更", "移動", "削除" options in that order.

#### Scenario: Registered novels show titles at any depth
- **WHEN** the user is in any directory within the library and subdirectories exist that are registered in the metadata database
- **THEN** those subdirectories are displayed with the novel title from the database instead of the ID-based folder name, regardless of how deeply they are nested

#### Scenario: Unregistered folders show folder name
- **WHEN** subdirectories exist that are NOT registered in the metadata database (organizational folders or legacy title-based folders)
- **THEN** those subdirectories are displayed with their folder name as-is

#### Scenario: User navigates into a registered novel folder
- **WHEN** the user selects a novel displayed with its database title
- **THEN** the file browser navigates into the corresponding ID-based folder and displays its text files

#### Scenario: User navigates back to parent directory
- **WHEN** the user is inside a subdirectory below the library root
- **THEN** a navigation option to return to the parent directory is available
- **AND** the navigation SHALL use platform-aware path resolution to determine the parent directory

#### Scenario: User navigates back to parent directory on Windows
- **WHEN** the user is inside a subdirectory with a Windows-style path (e.g., `C:\Users\name\NovelViewer\genre\book1`)
- **THEN** the parent directory SHALL be correctly resolved (e.g., `C:\Users\name\NovelViewer\genre`)

#### Scenario: User is at the library root directory
- **WHEN** the user is at the library root directory
- **THEN** the parent navigation control SHALL be disabled (or perform no action) so the file browser does not navigate above the library root

#### Scenario: Context menu includes move option for novels
- **WHEN** ユーザーが任意の深さの小説フォルダを右クリックする
- **THEN** コンテキストメニューに「更新」「タイトル変更」「移動」「削除」の4つのオプションがこの順序で表示される

### Requirement: Automatic refresh after download
The file browser SHALL automatically refresh its file listing when a download operation completes.

#### Scenario: Download completes
- **WHEN** a download completes
- **THEN** the file listing is automatically refreshed to include the newly downloaded files

### Requirement: TTS status fetch is observable on failure
When the file browser's TTS status query against the cached `TtsAudioDatabase` fails (e.g., the database is locked or corrupt), the system SHALL log the failure at WARNING level via `Logger('file_browser')` and SHALL fall back to treating all episodes as having no TTS data so that the file listing remains usable. The system SHALL NOT swallow the exception silently.

#### Scenario: TTS status query throws
- **WHEN** the file browser invokes the TTS status query and the database operation throws
- **THEN** a WARNING-level `LogRecord` is emitted on `Logger('file_browser')` containing the exception, and the file listing is rendered with no trailing TTS icons for any file

#### Scenario: TTS status query returns empty map
- **WHEN** the database is healthy but contains no TTS records for the current folder
- **THEN** no log record is emitted (this is the expected empty state, not a failure)

