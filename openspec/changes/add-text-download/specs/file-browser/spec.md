## ADDED Requirements

### Requirement: Automatic refresh after download
The file browser SHALL automatically refresh its file listing when a download operation completes.

#### Scenario: Download completes
- **WHEN** a download completes
- **THEN** the file listing is automatically refreshed to include the newly downloaded files

## REMOVED Requirements

### Requirement: Directory selection (removed)
The directory picker dialog ("folder open" button) has been removed. The file browser always starts with the default library directory (`~/Documents/NovelViewer/`), and directory navigation is limited to subdirectory traversal and parent navigation within the library.

#### Scenario: Directory picker is not available
- **WHEN** the user views the file browser toolbar
- **THEN** there is no "folder open" button; only the parent navigation button is available when inside a subdirectory
