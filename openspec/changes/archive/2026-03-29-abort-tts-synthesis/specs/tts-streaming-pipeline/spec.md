## MODIFIED Requirements

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
