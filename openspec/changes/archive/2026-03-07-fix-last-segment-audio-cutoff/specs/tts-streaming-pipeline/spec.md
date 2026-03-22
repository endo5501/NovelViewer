## MODIFIED Requirements

### Requirement: Audio buffer drain between segments
The system SHALL wait for the audio output device to finish draining its buffer after each segment's playback completes, including the last segment, before proceeding to cleanup or the next segment. The wait duration SHALL be configurable via a `bufferDrainDelay` constructor parameter on `TtsStreamingController`, with a default value suitable for Windows WASAPI (500ms). For intermediate segments, after the buffer drain delay, the system SHALL call `pause()` on the audio player to reset the internal `playing` flag to `false`. For the last segment, `pause()` is not required since no subsequent `play()` call will be made. The system SHALL NOT call `stop()` between segments, as `stop()` destroys the underlying platform player and kills any remaining audio in the output buffer. If the user stops playback during the buffer drain delay, the delay SHALL be skipped and stop SHALL proceed immediately.

#### Scenario: Buffer drain delay prevents audio cutoff
- **WHEN** segment N finishes playback (completed state is received) and segment N+1 is ready
- **THEN** the system waits for the configured buffer drain delay before loading segment N+1, ensuring the audio output device finishes playing all buffered samples

#### Scenario: pause() resets playing flag after buffer drain
- **WHEN** the buffer drain delay completes after segment N and segment N is not the last segment
- **THEN** the system calls `pause()` on the audio player, resetting the internal `playing` flag to `false` so that the subsequent `play()` call for segment N+1 is not a no-op

#### Scenario: Last segment waits for buffer drain before cleanup
- **WHEN** the last segment finishes playback (completed state is received)
- **THEN** the system waits for the configured buffer drain delay before disposing the audio player, ensuring the audio output device finishes playing all buffered samples

#### Scenario: stop() is not called between segments
- **WHEN** segment N completes and the system transitions to segment N+1
- **THEN** the system SHALL NOT call `stop()` on the audio player between segments, as `stop()` destroys the platform player (MediaKitPlayer) and kills audio in the WASAPI output buffer

#### Scenario: Buffer drain delay is zero in tests
- **WHEN** `TtsStreamingController` is constructed with `bufferDrainDelay: Duration.zero`
- **THEN** no delay occurs between segments, allowing tests to complete quickly without waiting for real audio device drain

#### Scenario: Buffer drain skipped on stop
- **WHEN** the user stops playback while the buffer drain delay is pending
- **THEN** the delay is skipped and stop proceeds immediately
