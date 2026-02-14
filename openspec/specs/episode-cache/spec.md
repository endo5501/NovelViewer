## ADDED Requirements

### Requirement: Episode cache database per novel folder
The system SHALL create and manage a SQLite database file (`episode_cache.db`) within each novel's download folder to store per-episode download metadata.

#### Scenario: Database is created on first download
- **WHEN** a novel is downloaded for the first time
- **THEN** the system creates `episode_cache.db` inside the novel's folder (e.g., `narou_n9669bk/episode_cache.db`)

#### Scenario: Database is opened on re-download
- **WHEN** a novel is re-downloaded and `episode_cache.db` already exists in the folder
- **THEN** the system opens the existing database and uses the cached data

#### Scenario: Database is deleted with folder
- **WHEN** the user deletes a novel's folder
- **THEN** the `episode_cache.db` file is deleted along with the folder, requiring no separate cleanup

#### Scenario: Database file is corrupted
- **WHEN** the `episode_cache.db` file is corrupted or unreadable
- **THEN** the system deletes the corrupted file, creates a new empty database, and proceeds to download all episodes as if no cache exists

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

### Requirement: Episode cache lookup
The system SHALL provide a method to look up cached episode metadata by URL.

#### Scenario: Cached episode is found
- **WHEN** the system queries the cache for an episode URL that has been previously downloaded
- **THEN** the cache returns the stored metadata including `last_modified` and `downloaded_at`

#### Scenario: Episode is not in cache
- **WHEN** the system queries the cache for an episode URL that has not been downloaded before
- **THEN** the cache returns null indicating a new episode

### Requirement: Episode cache bulk retrieval
The system SHALL provide a method to retrieve all cached episode records for a novel.

#### Scenario: All cached episodes are retrieved
- **WHEN** the system requests all cached records from the database
- **THEN** a map of URL to cache entries is returned for efficient lookup during the download loop
