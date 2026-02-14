## ADDED Requirements

### Requirement: Short story download
The system SHALL support downloading short stories (single-page novels) from Narou. When the index page contains no episode links but contains body text, the system SHALL treat it as a short story and extract the body content directly from the index page HTML.

#### Scenario: Short story is detected
- **WHEN** the index page HTML contains no episode links AND contains body text matching the body selectors
- **THEN** the system SHALL return a `NovelIndex` with an empty episodes list and the extracted body content in the `bodyContent` field

#### Scenario: Short story body text is saved
- **WHEN** a short story is detected (episodes list is empty and bodyContent is non-null)
- **THEN** the system SHALL save the body content as a single text file with episode index 1 and the novel title as the episode title

#### Scenario: Short story file naming
- **WHEN** a short story is saved
- **THEN** the file SHALL be named using the existing `formatEpisodeFileName` with index=1, title=novel title, and totalEpisodes=1, resulting in `1_{novel_title}.txt`

#### Scenario: Short story folder structure
- **WHEN** a short story is downloaded
- **THEN** the system SHALL create the same folder structure as multi-episode novels (`{site_type}_{novel_id}/`)

#### Scenario: Short story metadata registration
- **WHEN** a short story is downloaded successfully
- **THEN** the `DownloadResult` SHALL report episodeCount=1 and include the correct title, novelId, and folderName

#### Scenario: Short story episode cache
- **WHEN** a short story is downloaded
- **THEN** the system SHALL register the download in the episode cache using the index page URL as the cache key

#### Scenario: Short story re-download with cache
- **WHEN** a short story is re-downloaded and the episode cache contains an entry for the index page URL
- **THEN** the system SHALL check for updates via HEAD request using the same logic as multi-episode novels

#### Scenario: Short story text extraction preserves formatting
- **WHEN** the short story body text is extracted from the index page
- **THEN** the text extraction SHALL use the same parsing logic as episode pages (ruby tag preservation, paragraph separation, blank line handling)

#### Scenario: Index page has no episodes and no body text
- **WHEN** the index page HTML contains no episode links AND no body text matching the body selectors
- **THEN** the system SHALL return a `NovelIndex` with an empty episodes list and null bodyContent, and the download SHALL complete with episodeCount=0

#### Scenario: Short story progress display
- **WHEN** a short story is being downloaded
- **THEN** the progress callback SHALL be called with current=1, total=1
