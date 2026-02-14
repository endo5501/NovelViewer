## MODIFIED Requirements

### Requirement: File naming convention
Downloaded files SHALL follow a consistent naming convention with zero-padded numeric prefixes.

#### Scenario: Episode files are named with numeric prefix
- **WHEN** episodes are saved to disk
- **THEN** each file is named `{zero-padded index}_{episode title}.txt` (e.g., `001_プロローグ.txt`, `002_第一章.txt`)

#### Scenario: Novel directory is created using ID-based folder name
- **WHEN** a download is started
- **THEN** a subdirectory named `{site_type}_{novel_id}` is created inside the output directory, and all episode files are saved within it

#### Scenario: File name contains invalid characters
- **WHEN** an episode title contains characters invalid for file names (e.g., `\/:*?"<>|`)
- **THEN** the invalid characters are replaced with `_`

## ADDED Requirements

### Requirement: Novel metadata registration on download
The download service SHALL register novel metadata in the database upon successful download completion.

#### Scenario: New novel download registers metadata
- **WHEN** a novel download completes successfully
- **THEN** the system registers the novel's site type, novel ID, title, source URL, ID-based folder name, and episode count in the metadata database

#### Scenario: Re-download of existing novel updates metadata
- **WHEN** a novel that already exists in the database is downloaded again
- **THEN** the existing metadata record is updated with the current title, episode count, and updated timestamp

### Requirement: Novel ID extraction during download
The download service SHALL extract the site-specific novel ID from the URL before starting the download process.

#### Scenario: Novel ID is extracted for folder creation
- **WHEN** a download is initiated with a supported URL
- **THEN** the system extracts the novel ID via the site parser and uses it to construct the ID-based folder name

#### Scenario: Novel ID extraction fails
- **WHEN** the novel ID cannot be extracted from the URL
- **THEN** the download is aborted and an error message is displayed
