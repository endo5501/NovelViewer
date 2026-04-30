## Purpose

Drive incremental TTS synthesis and playback for an episode, persisting generated segments and surfacing observable failures during cleanup.
## Requirements
### Requirement: Unified streaming start
The system SHALL provide a single entry point `TtsStreamingController.start()` that automatically determines the appropriate mode based on existing data. If no episode exists, it SHALL start fresh generation with immediate playback. If an episode exists with matching text_hash, it SHALL begin playing segments using existing audio where available and generating audio on-demand for segments without audio_data. The controller SHALL accept text, fileName, an optional `startOffset`, an optional `resolveRefWavPath` callback, an optional `dictionaryRepository`, and a required `TtsEngineConfig` (typed; either `Qwen3EngineConfig` or `PiperEngineConfig`). All engine-specific parameters (modelDir, sampleRate, languageId, refWavPath, dicDir, synthesis parameters) SHALL be carried by the `TtsEngineConfig` rather than as separate `start()` parameters. The `resolveRefWavPath` callback SHALL be used to resolve per-segment ref_wav_path filenames from the database to absolute filesystem paths before passing them to the TTS engine. When a `dictionaryRepository` is provided, the system SHALL apply dictionary substitution to each segment's text when writing new segment records to `tts_segments.text`.

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

#### Scenario: 新規セグメント作成時に辞書変換済みテキストがDBに保存される
- **WHEN** `start()` が `dictionaryRepository` と共に呼ばれ、辞書に `{surface: "エルリック", reading: "えるりっく"}` が登録されており、「エルリック」を含むセグメントが新規作成される
- **THEN** `tts_segments.text` には「えるりっく」に変換済みのテキストが保存され、TTSエンジンもその変換済みテキストを受け取る

#### Scenario: 辞書なしで呼ばれた場合は変換を行わない
- **WHEN** `start()` が `dictionaryRepository` なし（null）で呼ばれる
- **THEN** セグメントテキストは変換されずにそのままDBに保存され、TTSエンジンに渡される

#### Scenario: 既存セグメント（audio_data=NULL）の再生成は保存済みテキストをそのまま使用する
- **WHEN** 既にDBに `tts_segments.text` が保存されているセグメント（audio_data=NULL）のオンデマンド生成が行われる
- **THEN** 追加の辞書変換は行わず、DBに保存されているテキストをそのままTTSエンジンに渡す

#### Scenario: Start with piper engine config
- **WHEN** `start()` is called with `config: PiperEngineConfig(dicDir: "models/piper/open_jtalk_dic", lengthScale: 0.8, ...)`
- **THEN** the TtsIsolate loads PiperTtsEngine with the specified dictionary path and applies lengthScale=0.8 before synthesis

#### Scenario: Start with qwen3 engine config
- **WHEN** `start()` is called with `config: Qwen3EngineConfig(refWavPath: "voice.wav", languageId: 2058, ...)`
- **THEN** the TtsIsolate loads TtsEngine (qwen3) with voice cloning support

#### Scenario: Piper engine ignores refWavPath
- **WHEN** `start()` is called with `config: PiperEngineConfig(...)` (no refWavPath field exists on Piper config)
- **THEN** voice cloning is not used, since `PiperEngineConfig` does not carry a `refWavPath` field at all

### Requirement: TtsIsolate engine type dispatch
The TtsIsolate SHALL accept a `TtsEngineType` parameter in `LoadModelMessage`. When engineType is `qwen3`, the isolate SHALL create and use `TtsEngine` (existing behavior). When engineType is `piper`, the isolate SHALL create and use `PiperTtsEngine`. The `LoadModelMessage` SHALL also accept an optional `dicDir` parameter for piper's OpenJTalk dictionary path, and optional synthesis parameters (lengthScale, noiseScale, noiseW). When a qwen3 model is loaded, the `ModelLoadedResponse` SHALL include the native context pointer address for abort support. The worker Isolate SHALL call `resetAbort()` before each synthesis to ensure the abort flag is clear.

#### Scenario: Load qwen3 engine in isolate
- **WHEN** a `LoadModelMessage` with engineType=qwen3 is sent to the isolate
- **THEN** the isolate creates a `TtsEngine`, loads the model, and responds with `ModelLoadedResponse(success: true)` including the context pointer address

#### Scenario: Load piper engine in isolate
- **WHEN** a `LoadModelMessage` with engineType=piper and dicDir="models/piper/open_jtalk_dic" is sent
- **THEN** the isolate creates a `PiperTtsEngine`, loads the model, and responds with `ModelLoadedResponse(success: true)` with ctxAddress=null (piper does not support abort)

#### Scenario: Synthesis with piper returns compatible result
- **WHEN** a `SynthesizeMessage` is sent to an isolate running PiperTtsEngine
- **THEN** the isolate responds with `SynthesisResultResponse` containing Float32List audio and sampleRate, same format as qwen3

#### Scenario: Reset abort before each synthesis
- **WHEN** a `SynthesizeMessage` is received by the worker Isolate running qwen3 engine
- **THEN** `resetAbort()` is called on the engine before starting synthesis

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
The streaming pipeline SHALL delegate per-segment playback (including buffer drain handling and `pause`-not-`stop` semantics) to a shared `SegmentPlayer` component. The `SegmentPlayer` SHALL wait for the audio output device to finish draining its buffer after each segment's playback completes, including the last segment, before proceeding. The wait duration SHALL be configurable via the `SegmentPlayer.bufferDrainDelay` constructor parameter (default 500ms, suitable for Windows WASAPI). For intermediate segments, after the buffer drain delay, the `SegmentPlayer` SHALL call `pause()` on the audio player. For the last segment, `pause()` is not required. The system SHALL NOT call `stop()` between segments, as `stop()` destroys the underlying platform player. If the user stops playback during the buffer drain delay, the delay SHALL be skipped and stop SHALL proceed immediately.

#### Scenario: Buffer drain delay prevents audio cutoff
- **WHEN** segment N finishes playback (completed state is received) and segment N+1 is ready
- **THEN** the `SegmentPlayer` waits for the configured buffer drain delay before loading segment N+1

#### Scenario: pause() resets playing flag after buffer drain
- **WHEN** the buffer drain delay completes after segment N and segment N is not the last segment
- **THEN** the `SegmentPlayer` calls `pause()` on the audio player, resetting the internal `playing` flag to `false`

#### Scenario: Last segment waits for buffer drain before cleanup
- **WHEN** the last segment finishes playback (completed state is received)
- **THEN** the `SegmentPlayer` waits for the configured buffer drain delay before disposing the audio player

#### Scenario: stop() is not called between segments
- **WHEN** segment N completes and the system transitions to segment N+1
- **THEN** the `SegmentPlayer` SHALL NOT call `stop()` on the audio player between segments

#### Scenario: Buffer drain delay is zero in tests
- **WHEN** the controller is constructed with a `SegmentPlayer` whose `bufferDrainDelay: Duration.zero` (or constructed via the convenience `bufferDrainDelay:` constructor parameter that propagates to the segment player)
- **THEN** no delay occurs between segments, allowing tests to complete quickly

#### Scenario: Buffer drain skipped on stop
- **WHEN** the user stops playback while the buffer drain delay is pending
- **THEN** the delay is skipped and stop proceeds immediately

### Requirement: TtsSession ownership of model-load and synthesis lifecycle
`TtsStreamingController` SHALL delegate model-load (`ensureModelLoaded`) and synthesis (`synthesize`) orchestration to a shared `TtsSession` component. The controller SHALL NOT maintain its own `_subscription`, `_modelLoaded` flag, or `_activeSynthesisCompleter` state — these SHALL live in `TtsSession` exclusively. The controller SHALL hold a single `TtsSession` instance for its lifetime and dispose it as part of `dispose()`.

#### Scenario: ensureModelLoaded is delegated
- **WHEN** the controller needs to ensure the TTS engine model is loaded with a given `TtsEngineConfig`
- **THEN** the controller calls `_session.ensureModelLoaded(config)` and the session manages the underlying isolate communication and the `_modelLoaded` flag

#### Scenario: synthesize is delegated
- **WHEN** the controller initiates synthesis for a segment
- **THEN** the controller calls `_session.synthesize(...)` and the session manages the active completer and abort wiring

#### Scenario: abort is delegated and idempotent
- **WHEN** the controller stops the pipeline while synthesis is in-flight
- **THEN** the controller calls `_session.abort()` exactly once; subsequent calls during the same abort cycle are no-ops

#### Scenario: dispose releases session resources
- **WHEN** the controller is disposed
- **THEN** `_session.dispose()` is called and the session's stream subscription, completer, and any pending isolate handles are released

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
The system SHALL support stopping the streaming pipeline at any time. Stopping SHALL first call `abort()` on the TtsIsolate to interrupt any in-progress synthesis via the shared context pointer, then wait for the synthesis to terminate, then dispose the TTS Isolate via the normal `DisposeMessage` flow to ensure `qwen3_tts_free` is called and GPU memory is released. Stopping SHALL halt both playback and generation, update the episode status to "partial" if generation was incomplete, clean up the TTS Isolate, and clean up temporary playback files. Generated segments SHALL be preserved in the database.

#### Scenario: Stop during streaming playback
- **WHEN** the user stops the streaming controller while segment 5 of 15 is playing and segments 0-7 have been generated
- **THEN** playback stops, generation stops, the episode status is set to "partial", the TTS Isolate is disposed, and segments 0-7 remain in the database

#### Scenario: Stop during active synthesis releases GPU memory
- **WHEN** the user stops the streaming controller while synthesis is actively running on the worker Isolate
- **THEN** abort() is called first to interrupt synthesis, the Isolate's event loop becomes responsive, DisposeMessage is processed, qwen3_tts_free is called, and GPU memory is released

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
The system SHALL use ruby text (furigana from `<rt>` elements) instead of base text when preparing text segments for TTS synthesis. When the text segmenter strips ruby HTML tags, it SHALL replace each `<ruby>` block with the content of its `<rt>` element rather than the base text. This ensures that the TTS engine receives the author-intended pronunciation. Additionally, the text segmenter SHALL apply length-based splitting (as defined by the tts-text-length-guard capability) after sentence-ending splitting, ensuring that long sentences are further divided before TTS synthesis.

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

#### Scenario: Long sentence without punctuation is split by length
- **WHEN** the text segmenter processes a 250-character sentence with no sentence-ending punctuation but a comma at position 180
- **THEN** the sentence is split into two segments at the comma position

### Requirement: Stop cleanup errors are observable
When the streaming controller's `stop()` cleanup path encounters an exception while releasing audio resources, the system SHALL log the exception at WARNING level via `Logger('tts.streaming')` rather than swallowing it silently. The cleanup SHALL still complete its state-clearing finally block (so `TtsPlaybackState` reaches `stopped` and `TtsHighlightRange` is set to `null` per existing requirements). If the same path encounters multiple errors, each is logged separately.

#### Scenario: Cleanup error is logged
- **WHEN** the streaming controller calls `stop()` and one of the resource-release operations (e.g., audio player tear-down) throws
- **THEN** a WARNING-level `LogRecord` is emitted on `Logger('tts.streaming')` carrying the exception, the state-clearing finally block still runs, and `TtsPlaybackState` ends in `stopped`

#### Scenario: Successful cleanup does not log
- **WHEN** the streaming controller calls `stop()` and all resources release cleanly
- **THEN** no cleanup warning is emitted (only the existing INFO/FINE diagnostics, if any)

### Requirement: TtsStreamingController accepts a Reader function for provider access
The `TtsStreamingController` constructor SHALL accept a `Reader` (typedef: `T Function<T>(ProviderListenable<T>)`) for accessing Riverpod state, rather than requiring a `ProviderContainer` instance. Call sites SHALL pass `ref.read` (or an equivalent reader) so the controller does not depend on `ProviderScope.containerOf(BuildContext)`. The controller's lifetime SHALL be permitted to outlive any single `WidgetRef` because the `Reader` function delegates to the underlying long-lived `ProviderContainer` internally.

#### Scenario: Controller is constructed with ref.read
- **WHEN** `TtsStreamingController` is instantiated by `TtsControlsBar`
- **THEN** the constructor receives `read: ref.read` and the controller stores the `Reader` for later use without holding a reference to a `ProviderContainer`

#### Scenario: Controller reads providers via the injected reader
- **WHEN** the controller needs to read `TtsSession`, `TtsEngineConfig`, or other provider values during `start()`/`stop()`/`abort()`
- **THEN** it invokes the injected `Reader` function (`_read(someProvider)`) rather than calling `ProviderScope.containerOf` or holding a stored `ProviderContainer`

#### Scenario: No ProviderScope.containerOf at the call site
- **WHEN** the source of `TtsControlsBar` (or any other call site that constructs `TtsStreamingController`) is inspected
- **THEN** no `ProviderScope.containerOf(context)` invocation appears for the purpose of constructing the controller

#### Scenario: Tests inject a custom reader
- **WHEN** a unit test constructs `TtsStreamingController` with a fake `Reader` returning fixture values
- **THEN** the controller operates against those fixture values without requiring a Riverpod `ProviderContainer` to be constructed in the test setup

