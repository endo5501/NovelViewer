## MODIFIED Requirements

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
