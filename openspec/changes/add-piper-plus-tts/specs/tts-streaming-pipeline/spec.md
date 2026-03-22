## MODIFIED Requirements

### Requirement: Unified streaming start
The system SHALL provide a single entry point `TtsStreamingController.start()` that automatically determines the appropriate mode based on existing data. If no episode exists, it SHALL start fresh generation with immediate playback. If an episode exists with matching text_hash, it SHALL begin playing segments using existing audio where available and generating audio on-demand for segments without audio_data. The controller SHALL accept text, fileName, modelDir, sampleRate, optional refWavPath, optional startOffset, optional resolveRefWavPath callback, optional dictionaryRepository parameters, and a required engineType parameter. The engineType parameter SHALL determine which TTS engine (qwen3-tts or piper-plus) the TtsIsolate uses for synthesis. When engineType is `piper`, the controller SHALL also accept a `dicDir` parameter for the OpenJTalk dictionary path and optional synthesis parameters (lengthScale, noiseScale, noiseW). The resolveRefWavPath callback SHALL be used to resolve per-segment ref_wav_path filenames from the database to absolute filesystem paths before passing them to the TTS engine. When a dictionaryRepository is provided, the system SHALL apply dictionary substitution to each segment's text when writing new segment records to `tts_segments.text`, so that the stored text is already the dictionary-converted form that the TTS engine will receive.

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

#### Scenario: Start with piper engine type
- **WHEN** `start()` is called with engineType=piper, dicDir="models/piper/open_jtalk_dic", and lengthScale=0.8
- **THEN** the TtsIsolate loads PiperTtsEngine with the specified dictionary path and applies lengthScale=0.8 before synthesis

#### Scenario: Start with qwen3 engine type
- **WHEN** `start()` is called with engineType=qwen3 and refWavPath="voice.wav"
- **THEN** the TtsIsolate loads TtsEngine (qwen3) with voice cloning support, same as current behavior

#### Scenario: Piper engine ignores refWavPath
- **WHEN** `start()` is called with engineType=piper and refWavPath is provided
- **THEN** the refWavPath is ignored since piper-plus does not support voice cloning

## ADDED Requirements

### Requirement: TtsIsolate engine type dispatch
The TtsIsolate SHALL accept a `TtsEngineType` parameter in `LoadModelMessage`. When engineType is `qwen3`, the isolate SHALL create and use `TtsEngine` (existing behavior). When engineType is `piper`, the isolate SHALL create and use `PiperTtsEngine`. The `LoadModelMessage` SHALL also accept an optional `dicDir` parameter for piper's OpenJTalk dictionary path, and optional synthesis parameters (lengthScale, noiseScale, noiseW).

#### Scenario: Load qwen3 engine in isolate
- **WHEN** a `LoadModelMessage` with engineType=qwen3 is sent to the isolate
- **THEN** the isolate creates a `TtsEngine`, loads the model, and responds with `ModelLoadedResponse(success: true)`

#### Scenario: Load piper engine in isolate
- **WHEN** a `LoadModelMessage` with engineType=piper and dicDir="models/piper/open_jtalk_dic" is sent
- **THEN** the isolate creates a `PiperTtsEngine`, loads the model with the dictionary path, and responds with `ModelLoadedResponse(success: true)`

#### Scenario: Synthesis with piper returns compatible result
- **WHEN** a `SynthesizeMessage` is sent to an isolate running PiperTtsEngine
- **THEN** the isolate responds with `SynthesisResultResponse` containing Float32List audio and sampleRate, same format as qwen3
