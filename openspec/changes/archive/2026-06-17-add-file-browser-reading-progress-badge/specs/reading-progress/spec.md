## ADDED Requirements

### Requirement: Bulk read reading progress

The system SHALL provide a bulk lookup operation that returns all stored reading progress records in a single query, so that the file browser can render per-novel progress for many novels without issuing one lookup per novel. Each returned record SHALL expose `novel_id` and `file_name` (no absolute path). When no records exist, the operation SHALL return an empty collection.

#### Scenario: Multiple progress records are returned at once
- **WHEN** the `reading_progress` table contains rows for "narou_n1234ab" (file_name "003_chapter3.txt") and "narou_n5678cd" (file_name "012_chapter12.txt")
- **THEN** the bulk operation SHALL return both records, each exposing its `novel_id` and `file_name`, from a single query

#### Scenario: No progress records stored
- **WHEN** the `reading_progress` table is empty
- **THEN** the bulk operation SHALL return an empty collection without error

#### Scenario: Bulk read failure is observable and non-fatal
- **WHEN** the bulk lookup operation throws (e.g., the database is locked)
- **THEN** a WARNING-level `LogRecord` SHALL be emitted on `Logger('reading_progress')` containing the exception
- **AND** the caller SHALL be able to degrade to "no progress" so the file listing remains usable
