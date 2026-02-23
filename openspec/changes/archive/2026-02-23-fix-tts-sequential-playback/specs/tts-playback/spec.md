## MODIFIED Requirements

### Requirement: Playback pipeline with prefetch
The system SHALL implement a sequential playback pipeline that generates and plays audio sentence by sentence. While the current sentence is playing, the system SHALL prefetch (pre-generate) the next sentence's audio to minimize gaps between sentences. Audio playback SHALL be initiated in a fire-and-forget manner (not awaited), and prefetch SHALL begin immediately after playback starts, before the current segment finishes playing.

#### Scenario: Sequential sentence playback
- **WHEN** playback is started on text with multiple sentences
- **THEN** sentences are played one after another in order, with highlight updating for each sentence

#### Scenario: Prefetch next sentence during playback
- **WHEN** the first sentence is being played
- **THEN** the second sentence's audio is being generated concurrently in the TTS Isolate

#### Scenario: Prefetch starts immediately after playback begins
- **WHEN** audio playback for a sentence is initiated
- **THEN** prefetch for the next sentence SHALL begin immediately after the play command is issued, without waiting for the current audio to finish playing

#### Scenario: Play prefetched audio without gap
- **WHEN** the current sentence finishes playing and the next sentence's audio is already generated
- **THEN** the next sentence begins playing immediately

#### Scenario: Wait for generation when prefetch is not ready
- **WHEN** the current sentence finishes playing but the next sentence's audio is still being generated
- **THEN** a loading indicator is displayed until the audio is ready, then playback resumes

#### Scenario: Playback reaches end of text
- **WHEN** the last sentence finishes playing
- **THEN** playback stops and the TTS highlight is cleared

#### Scenario: Audio play error is handled gracefully
- **WHEN** the audio player fails to play a segment (e.g., file not found, codec error)
- **THEN** playback is stopped and resources are cleaned up

### Requirement: TTS audio generation in Isolate
The system SHALL perform TTS audio generation in a separate Dart Isolate to avoid blocking the UI thread. The Isolate SHALL load the TTS model, accept synthesis requests, and return generated audio data to the main Isolate. The Isolate SHALL support graceful shutdown that ensures native TTS engine resources are properly released before the Isolate terminates.

#### Scenario: Generate audio in background Isolate
- **WHEN** a sentence is submitted for TTS generation
- **THEN** the audio is generated in a separate Isolate and the main Isolate receives the resulting audio data (Float32List) without UI freeze

#### Scenario: Load model in Isolate
- **WHEN** TTS playback is initiated for the first time
- **THEN** the TTS model is loaded within the Isolate using the configured model directory path

#### Scenario: Handle generation failure in Isolate
- **WHEN** TTS generation fails in the Isolate (e.g., invalid text, model error)
- **THEN** the main Isolate receives an error message and playback is stopped gracefully

#### Scenario: Graceful Isolate shutdown
- **WHEN** `dispose()` is called on the TTS Isolate
- **THEN** a dispose message is sent to the Isolate, the Isolate releases native TTS engine resources, and the Isolate terminates naturally before the method returns

#### Scenario: Graceful shutdown with timeout
- **WHEN** `dispose()` is called and the Isolate does not terminate within 2 seconds
- **THEN** the Isolate is forcefully killed to prevent indefinite blocking

#### Scenario: Dispose during active synthesis
- **WHEN** `dispose()` is called while the Isolate is processing a synthesis request
- **THEN** the dispose message is queued after the current synthesis completes, native resources are released, and the Isolate terminates without crashing
