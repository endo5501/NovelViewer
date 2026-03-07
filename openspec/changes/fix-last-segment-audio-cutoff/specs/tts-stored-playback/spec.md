## ADDED Requirements

### Requirement: Audio buffer drain before stop on last segment
The system SHALL wait for the audio output device to finish draining its buffer after the last segment's playback completes, before calling stop and disposing the audio player. The wait duration SHALL be configurable via a `bufferDrainDelay` constructor parameter on `TtsStoredPlayerController`, with a default value of 500ms. If the user stops playback during the buffer drain delay, the delay SHALL be skipped and stop SHALL proceed immediately.

#### Scenario: Last segment waits for buffer drain before stop
- **WHEN** the last segment finishes playback (completed state is received)
- **THEN** the system waits for the configured buffer drain delay before calling stop() and dispose(), ensuring the audio output device finishes playing all buffered samples

#### Scenario: Buffer drain delay is zero in tests
- **WHEN** `TtsStoredPlayerController` is constructed with `bufferDrainDelay: Duration.zero`
- **THEN** no delay occurs after the last segment, allowing tests to complete quickly

#### Scenario: Buffer drain skipped on user stop
- **WHEN** the user stops playback while the buffer drain delay is pending after the last segment
- **THEN** the delay is skipped and stop proceeds immediately

#### Scenario: Intermediate segments play without drain delay
- **WHEN** an intermediate segment finishes playback and the next segment is ready
- **THEN** the next segment begins playing immediately without a buffer drain delay
