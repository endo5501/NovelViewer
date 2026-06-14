## MODIFIED Requirements

### Requirement: TtsIsolate engine type dispatch
The TtsIsolate SHALL accept a `TtsEngineType` parameter in `LoadModelMessage`. When engineType is `qwen3`, the isolate SHALL create and use `TtsEngine` (existing behavior). When engineType is `piper`, the isolate SHALL create and use `PiperTtsEngine`. The `LoadModelMessage` SHALL also accept an optional `dicDir` parameter for piper's OpenJTalk dictionary path, and optional synthesis parameters (lengthScale, noiseScale, noiseW). The `LoadModelMessage` SHALL carry the session abort handle address (`abortHandleAddress`), which the worker wires into `qwen3_tts_init` for qwen3 models so the abort flag is checked during synthesis; `ModelLoadedResponse` SHALL NOT carry a synthesis context pointer. The worker Isolate SHALL call `resetAbort()` before each synthesis to ensure the abort flag is clear.

#### Scenario: Load qwen3 engine in isolate
- **WHEN** a `LoadModelMessage` with engineType=qwen3 is sent to the isolate
- **THEN** the isolate creates a `TtsEngine`, initializes the model with the session abort handle, and responds with `ModelLoadedResponse(success: true)`

#### Scenario: Load piper engine in isolate
- **WHEN** a `LoadModelMessage` with engineType=piper and dicDir="models/piper/open_jtalk_dic" is sent
- **THEN** the isolate creates a `PiperTtsEngine`, loads the model, and responds with `ModelLoadedResponse(success: true)` (piper does not check the abort flag)

#### Scenario: Synthesis with piper returns compatible result
- **WHEN** a `SynthesizeMessage` is sent to an isolate running PiperTtsEngine
- **THEN** the isolate responds with `SynthesisResultResponse` containing Float32List audio and sampleRate, same format as qwen3

#### Scenario: Reset abort before each synthesis
- **WHEN** a `SynthesizeMessage` is received by the worker Isolate running qwen3 engine
- **THEN** `resetAbort()` is called on the engine before starting synthesis
