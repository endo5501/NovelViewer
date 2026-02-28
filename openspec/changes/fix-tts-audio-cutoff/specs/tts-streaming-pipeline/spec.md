## ADDED Requirements

### Requirement: Audio buffer drain between segments
The system SHALL wait for the audio output device to finish draining its buffer after each segment's playback completes before proceeding to the next segment. The wait duration SHALL be configurable via a `bufferDrainDelay` constructor parameter on `TtsStreamingController`, with a default value suitable for Windows WASAPI (500ms). After the buffer drain delay, the system SHALL call `pause()` on the audio player to reset the internal `playing` flag to `false`. The system SHALL NOT call `stop()` between segments, as `stop()` destroys the underlying platform player and kills any remaining audio in the output buffer.

#### Scenario: Buffer drain delay prevents audio cutoff
- **WHEN** segment N finishes playback (completed state is received) and segment N+1 is ready
- **THEN** the system waits for the configured buffer drain delay before loading segment N+1, ensuring the audio output device finishes playing all buffered samples

#### Scenario: pause() resets playing flag after buffer drain
- **WHEN** the buffer drain delay completes after segment N
- **THEN** the system calls `pause()` on the audio player, resetting the internal `playing` flag to `false` so that the subsequent `play()` call for segment N+1 is not a no-op

#### Scenario: stop() is not called between segments
- **WHEN** segment N completes and the system transitions to segment N+1
- **THEN** the system SHALL NOT call `stop()` on the audio player between segments, as `stop()` destroys the platform player (MediaKitPlayer) and kills audio in the WASAPI output buffer

#### Scenario: Buffer drain delay is zero in tests
- **WHEN** `TtsStreamingController` is constructed with `bufferDrainDelay: Duration.zero`
- **THEN** no delay occurs between segments, allowing tests to complete quickly without waiting for real audio device drain

#### Scenario: Buffer drain skipped on stop
- **WHEN** the user stops playback while the buffer drain delay is pending
- **THEN** the delay is skipped and stop proceeds immediately

## MODIFIED Requirements

### Requirement: Producer-consumer pipeline coordination
The system SHALL run generation and playback concurrently using a producer-consumer pattern. The generation loop (producer) SHALL synthesize segments sequentially and notify readiness after each segment is stored. The playback loop (consumer) SHALL play segments in order, loading from the database. When the playback loop reaches a segment that has not yet been generated and has no stored audio_data, it SHALL wait for the generation notification before proceeding. When the playback loop reaches a segment that already has audio_data in the database (from prior generation or edit screen regeneration), it SHALL play that segment immediately without waiting for the generation loop. After each segment's playback completes, the system SHALL wait for the audio buffer drain delay and call `pause()` before loading the next segment.

#### Scenario: Playback proceeds while generation continues
- **WHEN** segment 0 has been generated and is playing, and segment 1 is being generated
- **THEN** playback of segment 0 continues uninterrupted while generation of segment 1 proceeds in parallel

#### Scenario: Next segment ready before current playback ends
- **WHEN** segment 1 has been generated and stored, and segment 0 is still playing
- **THEN** after segment 0 completes, the system waits for the buffer drain delay, calls `pause()`, and then begins segment 1 playback

#### Scenario: Playback catches up to generation
- **WHEN** segment 2 playback completes and segment 3 has not yet been generated and has no stored audio_data
- **THEN** the playback loop waits for the buffer drain delay, calls `pause()`, then waits for segment 3 generation to complete before playing it

#### Scenario: First segment triggers playback start
- **WHEN** the first segment (or first segment from startOffset) is generated and stored during fresh generation
- **THEN** playback begins immediately without waiting for subsequent segments

#### Scenario: Segment with pre-existing audio skips generation wait
- **WHEN** the playback loop reaches segment 5 which already has audio_data stored from a prior edit screen regeneration
- **THEN** the segment plays immediately from stored audio without waiting for the generation loop

#### Scenario: All segments play without audio cutoff
- **WHEN** 4 segments are played continuously using a BehaviorSubject-backed player state stream
- **THEN** all 4 segments SHALL be played to completion without any segment being skipped due to stale `completed` state replay
