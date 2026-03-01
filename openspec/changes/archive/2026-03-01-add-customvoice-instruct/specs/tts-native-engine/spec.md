## ADDED Requirements

### Requirement: C API for instruct-based text-to-speech synthesis
The C API SHALL provide functions to generate audio from text with instruct-based style control. The `qwen3_tts_synthesize_with_instruct` function SHALL accept text and instruct parameters. The `qwen3_tts_synthesize_with_voice_and_instruct` function SHALL accept text, reference audio path, and instruct parameters. When `instruct` is NULL, the behavior SHALL be identical to the non-instruct variants.

#### Scenario: Synthesize text with instruct without voice cloning
- **WHEN** `qwen3_tts_synthesize_with_instruct` is called with Japanese text and instruct text on a loaded context
- **THEN** audio data is generated using the instruct style control and accessible via `qwen3_tts_get_audio`, `qwen3_tts_get_audio_length`, and `qwen3_tts_get_sample_rate` (24000)

#### Scenario: Synthesize text with instruct and voice cloning
- **WHEN** `qwen3_tts_synthesize_with_voice_and_instruct` is called with Japanese text, a valid reference WAV file path, and instruct text
- **THEN** audio data is generated using both the reference voice characteristics and the instruct style control

#### Scenario: Instruct function with NULL instruct falls back to default
- **WHEN** `qwen3_tts_synthesize_with_instruct` is called with text and NULL instruct
- **THEN** the behavior is identical to calling `qwen3_tts_synthesize` with the same text

### Requirement: Dart FFI bindings for instruct synthesis
The Dart FFI binding class SHALL expose `synthesizeWithInstruct` and `synthesizeWithVoiceAndInstruct` as late final fields that bind to the corresponding C API functions. The binding signatures SHALL match the C API exactly.

#### Scenario: FFI bindings expose instruct synthesis functions
- **WHEN** the Dart FFI binding class is instantiated
- **THEN** `synthesizeWithInstruct` and `synthesizeWithVoiceAndInstruct` are available in addition to existing synthesis functions

### Requirement: TtsEngine instruct synthesis methods
The `TtsEngine` class SHALL provide `synthesizeWithInstruct(String text, String instruct)` and `synthesizeWithVoiceAndInstruct(String text, String refWavPath, String instruct)` methods. These methods SHALL ensure the model is loaded, convert all string parameters to native UTF-8, call the corresponding FFI function, free native memory, and extract audio data.

#### Scenario: Synthesize with instruct on loaded engine
- **WHEN** `synthesizeWithInstruct("こんにちは", "優しく")` is called on a loaded `TtsEngine`
- **THEN** the native `qwen3_tts_synthesize_with_instruct` is called and a `TtsSynthesisResult` is returned with valid audio data

#### Scenario: Synthesize with voice and instruct on loaded engine
- **WHEN** `synthesizeWithVoiceAndInstruct("こんにちは", "/path/ref.wav", "怒りで")` is called on a loaded `TtsEngine`
- **THEN** the native `qwen3_tts_synthesize_with_voice_and_instruct` is called and a `TtsSynthesisResult` is returned

#### Scenario: Instruct synthesis on unloaded engine throws
- **WHEN** `synthesizeWithInstruct` is called on an engine that has not loaded a model
- **THEN** a `TtsEngineException` is thrown with message 'Model not loaded'

### Requirement: TtsIsolate instruct support
The `TtsIsolate` SHALL accept an optional `instruct` parameter in its `synthesize` method. The `SynthesizeMessage` SHALL include an optional `instruct` field. The isolate entry point SHALL route to the appropriate `TtsEngine` method based on the combination of `refWavPath` and `instruct`.

#### Scenario: Synthesize with instruct only in isolate
- **WHEN** `synthesize("text", instruct: "Happy")` is called on `TtsIsolate`
- **THEN** the engine's `synthesizeWithInstruct` method is called

#### Scenario: Synthesize with voice and instruct in isolate
- **WHEN** `synthesize("text", refWavPath: "/path/ref.wav", instruct: "Sad")` is called
- **THEN** the engine's `synthesizeWithVoiceAndInstruct` method is called

#### Scenario: Backward compatible synthesis without instruct
- **WHEN** `synthesize("text")` is called without instruct
- **THEN** the engine's existing `synthesize` method is called (no change from current behavior)
