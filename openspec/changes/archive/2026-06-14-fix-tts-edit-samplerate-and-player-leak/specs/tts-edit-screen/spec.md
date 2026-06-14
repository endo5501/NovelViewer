## ADDED Requirements

### Requirement: Episode sample rate reflects active engine

The system SHALL set the `tts_episodes.sample_rate` column to the sample rate of the currently active TTS engine when creating an episode from the edit screen. The edit dialog SHALL resolve the active engine configuration via `TtsEngineConfig.resolveFromRef` and pass `config.sampleRate` to `loadSegments()`. The system SHALL NOT hard-code the sample rate. For the Qwen3 engine the value SHALL be 24000, and for the Piper engine the value SHALL be 22050.

#### Scenario: Episode created while Piper engine is active

- **WHEN** the active TTS engine is Piper (22050 Hz) and the edit screen creates an episode (via any segment operation that triggers episode creation)
- **THEN** the episode's `sample_rate` column is 22050

#### Scenario: Episode created while Qwen3 engine is active

- **WHEN** the active TTS engine is Qwen3 (24000 Hz) and the edit screen creates an episode
- **THEN** the episode's `sample_rate` column is 24000

#### Scenario: Controller stores the sample rate passed to loadSegments

- **WHEN** `loadSegments()` is called with a given sample rate and a segment operation subsequently creates the episode
- **THEN** the created episode's `sample_rate` column equals the value passed to `loadSegments()`

## MODIFIED Requirements

### Requirement: Dialog cleanup on close
The system SHALL dispose of the TTS Isolate (if loaded) when the edit dialog is closed. The system SHALL also dispose of the shared `SegmentPlayer` (and its underlying audio player) when the edit dialog is closed, so that the platform audio player created for the dialog session is released and does not leak across repeated open/close cycles. The `SegmentPlayer` SHALL be disposed before any temporary audio files are deleted, so that a player still holding a WAV file does not block its deletion.

#### Scenario: Close dialog with model loaded
- **WHEN** the user closes the edit dialog after having performed regeneration operations
- **THEN** the TTS Isolate is disposed and memory is freed

#### Scenario: SegmentPlayer disposed on close
- **WHEN** the user closes the edit dialog
- **THEN** the controller disposes the `SegmentPlayer`, releasing the underlying audio player

#### Scenario: Player disposed before temporary file cleanup
- **WHEN** the edit dialog is closed while preview playback resources exist
- **THEN** the `SegmentPlayer` is disposed before temporary audio files are deleted
