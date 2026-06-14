## MODIFIED Requirements

### Requirement: Audio buffer drain before stop on last segment
The buffer drain handling on the last segment SHALL be implemented inside the shared `SegmentPlayer`, not duplicated in the playback controller. The wait duration SHALL be configurable via the `SegmentPlayer.bufferDrainDelay` parameter, with a default of 500ms. The `TtsStreamingController` constructor SHALL accept a `bufferDrainDelay` parameter that propagates to its underlying `SegmentPlayer`, preserving existing test fixtures (`bufferDrainDelay: Duration.zero`). If the user stops playback during the buffer drain delay, the delay SHALL be skipped and stop SHALL proceed immediately.

#### Scenario: Last segment waits for buffer drain before stop
- **WHEN** the last segment finishes playback (completed state is received)
- **THEN** the `SegmentPlayer` waits for the configured buffer drain delay before calling its internal stop/pause sequence, ensuring the audio output device finishes playing all buffered samples

#### Scenario: Buffer drain delay is zero in tests
- **WHEN** `TtsStreamingController` is constructed with `bufferDrainDelay: Duration.zero`
- **THEN** the underlying `SegmentPlayer` is configured with `Duration.zero`, allowing tests to complete quickly

#### Scenario: Buffer drain skipped on user stop
- **WHEN** the user stops playback while the buffer drain delay is pending after the last segment
- **THEN** the `SegmentPlayer.stop()` skips the delay and stop proceeds immediately

#### Scenario: Intermediate segments play without drain delay
- **WHEN** an intermediate segment finishes playback and the next segment is ready
- **THEN** the `SegmentPlayer` proceeds to load the next segment after the configured drain delay (which is 500ms by default and `Duration.zero` in tests)
