## ADDED Requirements

### Requirement: Stop cleanup errors are observable
When the streaming controller's `stop()` cleanup path encounters an exception while releasing audio resources, the system SHALL log the exception at WARNING level via `Logger('tts.streaming')` rather than swallowing it silently. The cleanup SHALL still complete its state-clearing finally block (so `TtsPlaybackState` reaches `stopped` and `TtsHighlightRange` is set to `null` per existing requirements). If the same path encounters multiple errors, each is logged separately.

#### Scenario: Cleanup error is logged
- **WHEN** the streaming controller calls `stop()` and one of the resource-release operations (e.g., audio player tear-down) throws
- **THEN** a WARNING-level `LogRecord` is emitted on `Logger('tts.streaming')` carrying the exception, the state-clearing finally block still runs, and `TtsPlaybackState` ends in `stopped`

#### Scenario: Successful cleanup does not log
- **WHEN** the streaming controller calls `stop()` and all resources release cleanly
- **THEN** no cleanup warning is emitted (only the existing INFO/FINE diagnostics, if any)
