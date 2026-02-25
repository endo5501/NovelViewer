## ADDED Requirements

### Requirement: Unified streaming start
The system SHALL provide a single entry point `TtsStreamingController.start()` that automatically determines the appropriate mode based on existing data. If no episode exists, it SHALL start fresh generation with immediate playback. If an episode exists with status "partial" or "completed", it SHALL begin playing stored segments and generate remaining segments if needed. The controller SHALL accept text, fileName, modelDir, sampleRate, and optional refWavPath and startOffset parameters.

#### Scenario: Start fresh when no episode exists
- **WHEN** `start()` is called for a fileName with no existing episode in the database
- **THEN** the controller creates a new episode, begins generating the first segment, and starts playback as soon as the first segment is ready

#### Scenario: Resume from partial episode
- **WHEN** `start()` is called for a fileName with an existing episode in "partial" status and 5 of 15 segments stored
- **THEN** the controller begins playing from segment 0 and starts generating segment 5 onward in parallel

#### Scenario: Play completed episode
- **WHEN** `start()` is called for a fileName with an existing episode in "completed" status
- **THEN** the controller plays all stored segments without starting any generation

#### Scenario: Start from text offset
- **WHEN** `start()` is called with startOffset=120 and stored segments exist
- **THEN** playback begins from the segment whose text_offset is the largest value <= 120

### Requirement: Text hash validation
The system SHALL compute a SHA-256 hash of the episode text and store it in the `text_hash` column of the `tts_episodes` table. On each `start()` call, the system SHALL compare the current text hash with the stored hash. If they differ, the existing episode and all segments SHALL be deleted and generation SHALL restart from scratch.

#### Scenario: Text unchanged since last generation
- **WHEN** `start()` is called and the text hash matches the stored episode's text_hash
- **THEN** the existing episode data is reused

#### Scenario: Text changed since last generation
- **WHEN** `start()` is called and the text hash differs from the stored episode's text_hash
- **THEN** the existing episode and all segments are deleted, and a new episode is created with the updated text_hash

#### Scenario: Text hash stored on new episode creation
- **WHEN** a new episode is created during `start()`
- **THEN** the SHA-256 hash of the full text content is stored in the episode's text_hash column

### Requirement: Producer-consumer pipeline coordination
The system SHALL run generation and playback concurrently using a producer-consumer pattern. The generation loop (producer) SHALL synthesize segments sequentially and notify readiness after each segment is stored. The playback loop (consumer) SHALL play segments in order, loading from the database. When the playback loop reaches a segment that has not yet been generated, it SHALL wait for the generation notification before proceeding.

#### Scenario: Playback proceeds while generation continues
- **WHEN** segment 0 has been generated and is playing, and segment 1 is being generated
- **THEN** playback of segment 0 continues uninterrupted while generation of segment 1 proceeds in parallel

#### Scenario: Next segment ready before current playback ends
- **WHEN** segment 1 has been generated and stored, and segment 0 is still playing
- **THEN** segment 1 playback begins immediately after segment 0 finishes

#### Scenario: Playback catches up to generation
- **WHEN** segment 2 playback completes and segment 3 has not yet been generated
- **THEN** the playback loop waits for segment 3 generation to complete before playing it

#### Scenario: First segment triggers playback start
- **WHEN** the first segment (or first segment from startOffset) is generated and stored during fresh generation
- **THEN** playback begins immediately without waiting for subsequent segments

### Requirement: Waiting state display
The system SHALL set `TtsPlaybackState` to `waiting` when the playback loop is waiting for the generation loop to produce the next segment. The UI SHALL display a loading indicator while in this state. The highlight of the previously played segment SHALL be maintained during the waiting state.

#### Scenario: Waiting state activated when playback catches up
- **WHEN** the current segment finishes playing and the next segment has not been generated yet
- **THEN** `TtsPlaybackState` changes to `waiting` and a loading indicator is shown

#### Scenario: Waiting state deactivated when segment ready
- **WHEN** the next segment becomes available while in `waiting` state
- **THEN** `TtsPlaybackState` changes to `playing` and the segment begins playback

#### Scenario: Highlight preserved during waiting
- **WHEN** the system is in `waiting` state after playing segment N
- **THEN** the highlight range from segment N remains visible on the text viewer

### Requirement: Graceful stop with data preservation
The system SHALL support stopping the streaming pipeline at any time. Stopping SHALL halt both playback and generation, update the episode status to "partial" if generation was incomplete, clean up the TTS Isolate, and clean up temporary playback files. Generated segments SHALL be preserved in the database.

#### Scenario: Stop during streaming playback
- **WHEN** the user stops the streaming controller while segment 5 of 15 is playing and segments 0-7 have been generated
- **THEN** playback stops, generation stops, the episode status is set to "partial", the TTS Isolate is disposed, and segments 0-7 remain in the database

#### Scenario: Stop when all segments already generated
- **WHEN** the user stops the streaming controller and all segments have been generated (status "completed")
- **THEN** playback stops but the episode status remains "completed"

#### Scenario: Highlight and state cleared on stop
- **WHEN** the streaming controller is stopped
- **THEN** `TtsPlaybackState` is set to `stopped`, `TtsHighlightRange` is set to null, and temporary files are cleaned up

### Requirement: Pause and resume streaming playback
The system SHALL support pausing and resuming during streaming playback. Pause SHALL stop audio playback at the current position. Generation SHALL continue during pause. Resume SHALL restart audio from the paused position.

#### Scenario: Pause during playback
- **WHEN** the user pauses while segment 3 is playing
- **THEN** audio pauses at the current position, `TtsPlaybackState` changes to `paused`, and generation continues in the background

#### Scenario: Resume from pause
- **WHEN** the user resumes from a paused state
- **THEN** audio resumes from the paused position and `TtsPlaybackState` changes to `playing`

### Requirement: Streaming stops on episode navigation
The system SHALL stop the streaming pipeline when the user navigates to a different episode. Generated segments SHALL be preserved with the episode status set to "partial" if generation was incomplete.

#### Scenario: Navigate away during streaming
- **WHEN** the user selects a different episode while the streaming pipeline is active
- **THEN** the pipeline stops, generated segments are preserved, and the episode status is updated appropriately
