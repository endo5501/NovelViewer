## REMOVED Requirements

### Requirement: Playback pipeline with prefetch
**Reason**: Replaced by batch generation + stored playback. Audio is now pre-generated and saved to database, eliminating the need for real-time synthesis with prefetch.
**Migration**: Use `tts-batch-generation` for audio generation and `tts-stored-playback` for playback.

### Requirement: Audio file management
**Reason**: Temporary WAV file management for real-time synthesis is no longer needed. Audio is stored as BLOBs in SQLite database. Temporary files are only used transiently during playback (reading BLOB to file for just_audio).
**Migration**: Audio storage is handled by `tts-audio-storage`. Temporary playback files are managed by `tts-stored-playback`.

### Requirement: Playback controller lifecycle in text viewer
**Reason**: The `TtsPlaybackController` with its real-time synthesis pipeline is replaced by separate `TtsGenerationController` and `TtsStoredPlayerController`. The text viewer panel manages these new controllers instead.
**Migration**: Use `TtsGenerationController` for batch generation and `TtsStoredPlayerController` for playback. The text viewer panel manages their lifecycle based on the new UI state machine.

### Requirement: Concrete playback adapter implementations
**Reason**: `WavWriterAdapter` and `FileCleanerImpl` are no longer needed as separate abstractions. WAV writing is done directly to bytes for DB storage. File cleanup is handled internally by the stored player controller. `JustAudioPlayer` is retained and reused by the new stored player.
**Migration**: `JustAudioPlayer` continues to be used. `WavWriter` is used directly for byte conversion. `TtsFileCleaner` abstraction is removed.

## MODIFIED Requirements

### Requirement: TTS playback state management
The system SHALL expose TTS state via Riverpod providers. The state SHALL include: audio generation state (none, generating, ready), playback status (stopped, playing, paused), generation progress (current segment index, total count), the currently highlighted text range, and error information.

#### Scenario: Initial state is none/stopped
- **WHEN** the application starts
- **THEN** the TTS audio state is "none", the playback state is "stopped", and no highlight range is set

#### Scenario: State transitions to generating
- **WHEN** the user presses the "読み上げ音声生成" button
- **THEN** the TTS audio state changes to "generating" with progress 0/N

#### Scenario: State transitions to ready on generation complete
- **WHEN** all segments have been generated and saved
- **THEN** the TTS audio state changes to "ready"

#### Scenario: State transitions to playing on play
- **WHEN** the user presses play with stored audio available
- **THEN** the playback state changes to "playing" and the highlight range is set

#### Scenario: State transitions to paused
- **WHEN** the user presses pause during playback
- **THEN** the playback state changes to "paused" and the highlight range remains set

#### Scenario: State transitions to stopped on stop
- **WHEN** playback is stopped (by user action or end of segments)
- **THEN** the playback state changes to "stopped" and the highlight range is cleared

#### Scenario: State returns to none on delete
- **WHEN** the user deletes stored audio
- **THEN** the TTS audio state changes to "none"

### Requirement: Playback start position
The system SHALL determine the playback start position based on the current text selection. If text is selected, playback SHALL begin from the segment containing the start of the selection, identified by querying the database for the segment with the largest `text_offset` <= the selection offset. If no text is selected, playback SHALL begin from the first segment.

#### Scenario: Start from selected text position
- **WHEN** the user has selected text starting at offset 50 and presses play
- **THEN** playback begins from the segment whose text_offset is the largest value <= 50

#### Scenario: Start from beginning when no selection
- **WHEN** no text is selected and the user presses play
- **THEN** playback begins from segment 0

### Requirement: Playback stop conditions
The system SHALL stop TTS playback when the user presses the stop button or navigates to a different episode. Page navigation within the same episode (arrow keys, swipe, mouse wheel) SHALL NOT stop playback.

#### Scenario: Stop playback via stop button
- **WHEN** the user presses the stop button during TTS playback
- **THEN** audio playback stops and the highlight is cleared

#### Scenario: Stop playback on episode change
- **WHEN** the user selects a different episode during TTS playback
- **THEN** playback stops and the highlight is cleared

#### Scenario: Continue playback on page navigation within episode
- **WHEN** the user presses an arrow key during TTS playback in vertical mode
- **THEN** playback continues (auto page turn handles navigation)
