## MODIFIED Requirements

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

## ADDED Requirements

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
