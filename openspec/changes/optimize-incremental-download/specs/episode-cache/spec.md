## MODIFIED Requirements

### Requirement: Episode cache schema
The episode cache database SHALL store episode metadata with the following schema: `url` (TEXT, primary key), `episode_index` (INTEGER), `title` (TEXT), `last_modified` (TEXT, nullable), `downloaded_at` (TEXT). The `last_modified` field stores the episode update date extracted from the index page (instead of the HTTP Last-Modified header).

#### Scenario: Cache entry is stored after download
- **WHEN** an episode is successfully downloaded
- **THEN** the system stores a record with the episode's URL, index, title, the episode update date from the index page as `last_modified` (if available), and the current timestamp as `downloaded_at`

#### Scenario: Cache entry is updated on re-download
- **WHEN** an episode that already exists in the cache is re-downloaded due to detected changes
- **THEN** the existing cache record is replaced with updated `last_modified` (new index page date) and `downloaded_at` values

#### Scenario: Update date is not available from index page
- **WHEN** the index page does not provide an update date for the episode
- **THEN** the `last_modified` field is stored as null
