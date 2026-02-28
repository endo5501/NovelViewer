## Requirements

### Requirement: Unified streaming start
The system SHALL provide a single entry point `TtsStreamingController.start()` that automatically determines the appropriate mode based on existing data. If no episode exists, it SHALL start fresh generation with immediate playback. If an episode exists with matching text_hash, it SHALL begin playing segments using existing audio where available and generating audio on-demand for segments without audio_data. The controller SHALL accept text, fileName, modelDir, sampleRate, optional refWavPath, optional startOffset, and optional resolveRefWavPath callback parameters. The resolveRefWavPath callback SHALL be used to resolve per-segment ref_wav_path filenames from the database to absolute filesystem paths before passing them to the TTS engine.

#### Scenario: Start fresh when no episode exists
- **WHEN** `start()` is called for a fileName with no existing episode in the database
- **THEN** the controller creates a new episode, begins generating the first segment, and starts playback as soon as the first segment is ready

#### Scenario: Resume from partial episode
- **WHEN** `start()` is called for a fileName with an existing episode in "partial" status and 5 of 15 segments stored (all with audio_data)
- **THEN** the controller begins playing from segment 0 and starts generating segment 5 onward in parallel

#### Scenario: Play completed episode
- **WHEN** `start()` is called for a fileName with an existing episode in "completed" status and all segments have audio_data
- **THEN** the controller plays all stored segments without starting any generation

#### Scenario: Start from text offset
- **WHEN** `start()` is called with startOffset=120 and stored segments exist
- **THEN** playback begins from the segment whose text_offset is the largest value <= 120

#### Scenario: Play episode with mixed generation state
- **WHEN** `start()` is called for an episode where segments 0, 2, 3 have audio_data but segment 1 has audio_data=NULL (edited but not regenerated)
- **THEN** segments 0 plays from stored audio, segment 1 is generated on-demand using its DB text and ref_wav_path then played, segments 2 and 3 play from stored audio

#### Scenario: On-demand generation uses segment DB text
- **WHEN** playback reaches a segment with audio_data=NULL whose DB text is "山奥のいっけんや" (edited from original "山奥の一軒家")
- **THEN** the TTS engine receives "山奥のいっけんや" as input for generation

#### Scenario: On-demand generation uses segment ref_wav_path
- **WHEN** playback reaches a segment with audio_data=NULL that has a per-segment ref_wav_path set to "narrator.wav"
- **THEN** the TTS engine uses the resolved absolute path of "narrator.wav" for generation, not the global setting

#### Scenario: On-demand generation resolves ref_wav_path filename to absolute path
- **WHEN** playback reaches a segment with audio_data=NULL and ref_wav_path="custom_voice.wav" in the database, and a resolveRefWavPath callback is provided
- **THEN** the system calls resolveRefWavPath("custom_voice.wav") and passes the resulting absolute path to the TTS engine

#### Scenario: On-demand generation stores NULL ref_wav_path for new segments
- **WHEN** a segment without a DB record is generated on-demand using the global reference audio
- **THEN** the inserted segment record SHALL have ref_wav_path=NULL (indicating "use global setting"), not the resolved full path of the global reference audio

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

### Requirement: Ruby text used for TTS synthesis
The system SHALL use ruby text (furigana from `<rt>` elements) instead of base text when preparing text segments for TTS synthesis. When the text segmenter strips ruby HTML tags, it SHALL replace each `<ruby>` block with the content of its `<rt>` element rather than the base text. This ensures that the TTS engine receives the author-intended pronunciation.

#### Scenario: Ruby text extracted for single ruby tag
- **WHEN** the text contains `<ruby>一軒家<rt>いっけんや</rt></ruby>`
- **THEN** the text segmenter produces "いっけんや" as the text for that portion

#### Scenario: Ruby text extracted for multiple ruby tags
- **WHEN** the text contains `<ruby>魔法<rt>まほう</rt></ruby>の<ruby>杖<rt>つえ</rt></ruby>`
- **THEN** the text segmenter produces "まほうのつえ" as the text for that portion

#### Scenario: Ruby text extracted with rp elements present
- **WHEN** the text contains `<ruby>漢字<rp>(</rp><rt>かんじ</rt><rp>)</rp></ruby>`
- **THEN** the text segmenter produces "かんじ" as the text for that portion

#### Scenario: Ruby text extracted with rb elements present
- **WHEN** the text contains `<ruby><rb>八百万</rb><rp>（</rp><rt>やおよろず</rt><rp>）</rp></ruby>`
- **THEN** the text segmenter produces "やおよろず" as the text for that portion

#### Scenario: Mixed plain and ruby text segmented correctly
- **WHEN** the text contains `これは<ruby>漢字<rt>かんじ</rt></ruby>です。`
- **THEN** the text segmenter produces "これはかんじです。" as the full segment text

#### Scenario: Text hash changes trigger regeneration
- **WHEN** a previously generated episode's text is re-segmented with ruby text extraction
- **THEN** the text hash differs from the stored hash and the existing audio is automatically regenerated
