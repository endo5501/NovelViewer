## MODIFIED Requirements

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
