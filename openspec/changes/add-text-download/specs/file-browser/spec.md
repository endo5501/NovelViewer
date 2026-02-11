## ADDED Requirements

### Requirement: Automatic refresh after download
The file browser SHALL automatically refresh its file listing when a download operation completes and the downloaded files are within the currently displayed directory.

#### Scenario: Download completes in current directory
- **WHEN** a download completes and the output directory matches the current file browser directory
- **THEN** the file listing is automatically refreshed to include the newly downloaded files

#### Scenario: Download completes in a different directory
- **WHEN** a download completes and the output directory differs from the current file browser directory
- **THEN** the file browser navigates to the download output directory and displays its contents

#### Scenario: Download completes with no directory selected
- **WHEN** a download completes and no directory is currently selected in the file browser
- **THEN** the file browser navigates to the download output directory and displays its contents
