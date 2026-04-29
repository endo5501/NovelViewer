## ADDED Requirements

### Requirement: TTS status fetch is observable on failure
When the file browser's TTS status query against the cached `TtsAudioDatabase` fails (e.g., the database is locked or corrupt), the system SHALL log the failure at WARNING level via `Logger('file_browser')` and SHALL fall back to treating all episodes as having no TTS data so that the file listing remains usable. The system SHALL NOT swallow the exception silently.

#### Scenario: TTS status query throws
- **WHEN** the file browser invokes the TTS status query and the database operation throws
- **THEN** a WARNING-level `LogRecord` is emitted on `Logger('file_browser')` containing the exception, and the file listing is rendered with no trailing TTS icons for any file

#### Scenario: TTS status query returns empty map
- **WHEN** the database is healthy but contains no TTS records for the current folder
- **THEN** no log record is emitted (this is the expected empty state, not a failure)
