## MODIFIED Requirements

### Requirement: Database initialization
The system SHALL initialize a SQLite database on application startup to manage novel metadata. On Windows, the database file SHALL be placed in the same directory as the exe file. On macOS/Linux, the system SHALL use the default `getDatabasesPath()` location.

#### Scenario: First launch creates database
- **WHEN** the application starts for the first time and no database file exists
- **THEN** the system creates a SQLite database file with the novels table schema

#### Scenario: Subsequent launch uses existing database
- **WHEN** the application starts and the database file already exists
- **THEN** the system opens the existing database without data loss

#### Scenario: Windows database location
- **WHEN** the application starts on Windows
- **THEN** the database file SHALL be created at `<exe_directory>/novel_metadata.db`

#### Scenario: macOS database location unchanged
- **WHEN** the application starts on macOS
- **THEN** the database file SHALL be created in the `getDatabasesPath()` directory (existing behavior)
