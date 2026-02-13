## ADDED Requirements

### Requirement: Database initialization
The system SHALL initialize a SQLite database on application startup to manage novel metadata.

#### Scenario: First launch creates database
- **WHEN** the application starts for the first time and no database file exists
- **THEN** the system creates a SQLite database file in the library directory with the novels table schema

#### Scenario: Subsequent launch uses existing database
- **WHEN** the application starts and the database file already exists
- **THEN** the system opens the existing database without data loss

### Requirement: Novel metadata storage
The system SHALL store novel metadata in a `novels` table with the following fields: auto-increment ID, site type, novel ID, title, URL, folder name, episode count, downloaded timestamp, and updated timestamp.

#### Scenario: Novel metadata is registered after download
- **WHEN** a novel download completes successfully
- **THEN** a record is inserted into the novels table with the site type, novel ID, title, source URL, ID-based folder name, episode count, and current timestamp

#### Scenario: Duplicate novel download updates existing record
- **WHEN** a novel with the same site type and novel ID is downloaded again
- **THEN** the existing record is updated with the new title, episode count, and updated timestamp instead of creating a duplicate

### Requirement: Novel metadata retrieval
The system SHALL provide methods to query novel metadata from the database.

#### Scenario: Retrieve all novels
- **WHEN** the file browser requests the novel list
- **THEN** the system returns all novel records from the database ordered by title

#### Scenario: Retrieve novel by folder name
- **WHEN** the system needs to resolve a folder name to a novel title
- **THEN** the system returns the novel record matching the given folder name, or null if not found

#### Scenario: Retrieve novel by site type and novel ID
- **WHEN** the system checks if a novel already exists before download
- **THEN** the system returns the novel record matching the given site type and novel ID, or null if not found

### Requirement: ID-based folder naming
The system SHALL use the format `{site_type}_{novel_id}` for novel storage folders.

#### Scenario: Narou novel folder naming
- **WHEN** a novel is downloaded from narou with ncode `n1234ab`
- **THEN** the folder name SHALL be `narou_n1234ab`

#### Scenario: Kakuyomu novel folder naming
- **WHEN** a novel is downloaded from kakuyomu with work ID `16816452220917939820`
- **THEN** the folder name SHALL be `kakuyomu_16816452220917939820`

### Requirement: Novel ID extraction interface
Each site parser SHALL provide a method to extract the site-specific novel ID from a URL and a property to identify the site type.

#### Scenario: Extract narou novel ID from URL
- **WHEN** the URL `https://ncode.syosetu.com/n1234ab/` is provided to the narou parser
- **THEN** the extracted novel ID is `n1234ab`

#### Scenario: Extract kakuyomu novel ID from URL
- **WHEN** the URL `https://kakuyomu.jp/works/16816452220917939820` is provided to the kakuyomu parser
- **THEN** the extracted novel ID is `16816452220917939820`

#### Scenario: Site type identification
- **WHEN** the site type is queried from a parser
- **THEN** the narou parser returns `narou` and the kakuyomu parser returns `kakuyomu`
