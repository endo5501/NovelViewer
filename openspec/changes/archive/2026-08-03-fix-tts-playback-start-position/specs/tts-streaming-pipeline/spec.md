## MODIFIED Requirements

### Requirement: Unified streaming start
The system SHALL provide a single entry point `TtsStreamingController.start()` that automatically determines the appropriate mode based on existing data. If no episode exists, it SHALL start fresh generation with immediate playback. If an episode exists with matching text_hash, it SHALL begin playing segments using existing audio where available and generating audio on-demand for segments without audio_data. The controller SHALL accept text, fileName, an optional `startOffset`, an optional `resolveRefWavPath` callback, an optional `dictionaryRepository`, and a required `TtsEngineConfig` (typed; either `Qwen3EngineConfig` or `PiperEngineConfig`). All engine-specific parameters (modelDir, sampleRate, languageId, refWavPath, dicDir, synthesis parameters) SHALL be carried by the `TtsEngineConfig` rather than as separate `start()` parameters. The `resolveRefWavPath` callback SHALL be used to resolve per-segment ref_wav_path filenames from the database to absolute filesystem paths before passing them to the TTS engine. When a `dictionaryRepository` is provided, the system SHALL apply dictionary substitution to each segment's text when writing new segment records to `tts_segments.text`.

`startOffset` SHALL be interpreted in plain-text coordinates (the text after ruby markup has been replaced by its base text), the same coordinate space as `TextSegment.offset`. The starting segment SHALL be resolved against the segment list produced by segmenting `text`, NOT by querying the stored segment rows in the database, so that a segment with no database row is still a valid start position. When no segment satisfies `offset <= startOffset`, or `startOffset` is null, generation and playback SHALL start from segment 0.

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
- **WHEN** `start()` is called with startOffset=120
- **THEN** playback begins from the segment of the freshly segmented text whose offset is the largest value <= 120

#### Scenario: Start from a text offset with no stored segments
- **WHEN** `start()` is called with startOffset=120 for an episode whose database holds no segment rows at all
- **THEN** playback begins from the segment whose offset is the largest value <= 120, generating its audio on demand, rather than from segment 0

#### Scenario: Start from a text offset beyond the stored segments
- **WHEN** `start()` is called with startOffset=900 for an episode whose stored segment rows cover only offsets 0-300
- **THEN** playback begins from the segment of the freshly segmented text whose offset is the largest value <= 900, not from the last stored segment

#### Scenario: Start offset before the first segment falls back to segment 0
- **WHEN** `start()` is called with a startOffset smaller than the first segment's offset
- **THEN** playback begins from segment 0

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

### Requirement: Synthesis failure is surfaced and never masquerades as completed

The streaming pipeline SHALL distinguish a genuine synthesis/model-load failure from a user-initiated stop and from normal completion. Within the generation/playback loop, when `ensureModelLoaded` returns `false` or `synthesize` returns `null` while `_stopped` is `false`, the system SHALL treat this as a failure (not a stop). On `start()` completion the system SHALL set the episode status as follows: if the run was stopped by the user, the status SHALL be `partial`; if the run failed and at least one stored segment has audio data, the status SHALL be `partial`; if the run failed and no stored segment has audio data, the system SHALL delete the episode record so that the file's derived `TtsAudioState` reverts to `none`; if the run finished normally, the status SHALL be `completed` only when every segment of the text has stored audio, and `partial` otherwise. A run that began at a `startOffset` past segment 0 covers only that suffix, so the segments before the start position remain ungenerated and the episode SHALL NOT be reported as `completed`. The system SHALL NOT mark an episode `completed` when a failure occurred. The `start()` method SHALL return a `TtsStartOutcome` value (`completed`, `stopped`, or `failed`) describing the result so callers can react to failures; `completed` describes the run finishing without failure or stop and is independent of the persisted episode status. A failure that kept some audio and a failure with no audio both return `failed` (the difference is reflected in the persisted episode status, not the outcome).

The system MUST rely on `_stopped` being set before `abort()` during `stop()`, which guarantees that any `false`/`null` returned because of an abort is observed with `_stopped` already `true`; therefore a `false`/`null` observed while `_stopped` is `false` is always a real engine failure.

#### Scenario: Model-load failure with no audio deletes the episode
- **WHEN** `start()` is called, no prior audio exists, and `ensureModelLoaded` returns `false` while the user has not stopped
- **THEN** no segment is marked, the episode record is deleted, the derived `TtsAudioState` for the file becomes `none`, and `start()` returns `failed`

#### Scenario: Mid-stream synthesis failure with partial audio yields partial
- **WHEN** `start()` generates and stores audio for the first 2 of 5 segments, then `synthesize` returns `null` for segment 2 while the user has not stopped
- **THEN** the episode status is set to `partial`, the 2 stored segments are preserved, and `start()` returns `failed`

#### Scenario: User stop is not treated as a failure
- **WHEN** the user stops the pipeline mid-generation so that `_stopped` is `true` before the in-flight `synthesize` completes with `null`
- **THEN** the episode status is set to `partial`, no episode is deleted, and `start()` returns `stopped` (not `failed`)

#### Scenario: Successful run completes normally
- **WHEN** `start()` generates audio for all segments without any failure or stop
- **THEN** the episode status is set to `completed` and `start()` returns `completed`

#### Scenario: Run started past a gap stays partial
- **WHEN** `start()` is called with a `startOffset` resolving to segment 4 of 5, segments 2 and 3 have no stored audio, and the run reaches the end without failure or stop
- **THEN** the episode status is set to `partial` (not `completed`) so the file browser does not show it as fully generated and an MP3 export does not silently omit the ungenerated segments, while `start()` still returns `completed`
