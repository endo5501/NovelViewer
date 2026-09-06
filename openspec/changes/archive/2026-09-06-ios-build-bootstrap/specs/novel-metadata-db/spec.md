## MODIFIED Requirements

### Requirement: Database initialization
The system SHALL initialize a SQLite database on application startup to manage novel metadata. On Windows, the database file SHALL be placed in the same directory as the exe file. On iOS, the database file SHALL be placed in the application support directory, NOT in the documents directory, because the documents directory is exposed to the Files app and this database holds non-reproducible data that is deliberately not auto-recovered on corruption. On macOS/Linux, the system SHALL use the default `getDatabasesPath()` location.

The platform-to-location mapping SHALL be expressed as a pure function that takes the platform flags as parameters, so every branch is testable without `dart:io`.

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

#### Scenario: iOS database location
- **WHEN** the application starts on iOS
- **THEN** the database file SHALL be created in the application support directory

#### Scenario: iOS database is not exposed to the Files app
- **WHEN** the application has started on iOS and the Files app is opened
- **THEN** `novel_metadata.db` is not listed alongside the novel library

#### Scenario: Location resolution is testable without dart:io
- **WHEN** the location-resolving function is called with each combination of platform flags
- **THEN** it returns the executable-directory location for Windows, the application-support location for iOS, and the platform-default location otherwise
