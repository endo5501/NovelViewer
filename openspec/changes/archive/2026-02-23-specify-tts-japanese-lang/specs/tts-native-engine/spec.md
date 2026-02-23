## ADDED Requirements

### Requirement: C API for language configuration
The C API SHALL provide a function to set the synthesis language on a TTS context. The function `qwen3_tts_set_language` SHALL accept a context pointer and a language ID (`int32_t`). The language ID SHALL be stored in the context and used by subsequent calls to `qwen3_tts_synthesize` and `qwen3_tts_synthesize_with_voice`. The context SHALL default to Japanese (`2058`) when no language is explicitly set.

#### Scenario: Set language to Japanese
- **WHEN** `qwen3_tts_set_language` is called with language ID `2058` on a loaded context
- **THEN** subsequent synthesis calls use Japanese language for audio generation

#### Scenario: Default language is Japanese
- **WHEN** a new context is created via `qwen3_tts_init` without calling `qwen3_tts_set_language`
- **THEN** synthesis calls use Japanese (`2058`) as the default language

#### Scenario: Set language with null context
- **WHEN** `qwen3_tts_set_language` is called with a null context pointer
- **THEN** the function returns without error (no-op)

### Requirement: TtsEngine language configuration
The `TtsEngine` class SHALL provide a `setLanguage` method that accepts an integer language ID and calls the native `qwen3_tts_set_language` function. The class SHALL define a `languageJapanese` constant with value `2058`. The `setLanguage` method SHALL only be callable when the model is loaded.

#### Scenario: Set language on loaded engine
- **WHEN** `setLanguage` is called with `TtsEngine.languageJapanese` on a loaded `TtsEngine`
- **THEN** the native `qwen3_tts_set_language` is called with the context and language ID `2058`

#### Scenario: Set language on unloaded engine throws
- **WHEN** `setLanguage` is called on a `TtsEngine` that has not loaded a model
- **THEN** a `TtsEngineException` is thrown with message 'Model not loaded'

### Requirement: TtsIsolate language support
The `TtsIsolate` SHALL accept a language ID in its `loadModel` method. The `LoadModelMessage` SHALL include a `languageId` field. After loading the model in the Isolate, the engine SHALL call `setLanguage` with the provided language ID. The default language ID SHALL be `2058` (Japanese).

#### Scenario: Load model with Japanese language in Isolate
- **WHEN** `TtsIsolate.loadModel` is called with `languageId: 2058`
- **THEN** the Isolate loads the model and sets the language to Japanese before responding with `ModelLoadedResponse(success: true)`

#### Scenario: Load model with default language
- **WHEN** `TtsIsolate.loadModel` is called without specifying `languageId`
- **THEN** the Isolate loads the model and sets the language to the default (`2058`)

## MODIFIED Requirements

### Requirement: Dart FFI bindings
The system SHALL provide Dart FFI bindings that wrap the C API functions. The bindings SHALL load the shared library from the platform-appropriate location. All FFI calls SHALL be designed to run safely within a Dart Isolate.

#### Scenario: Load shared library on macOS
- **WHEN** the Dart FFI bindings are initialized on macOS
- **THEN** the shared library is loaded from the app bundle's Frameworks directory

#### Scenario: Load shared library on Windows
- **WHEN** the Dart FFI bindings are initialized on Windows
- **THEN** the shared library is loaded from the executable's directory

#### Scenario: FFI bindings expose all C API functions
- **WHEN** the Dart FFI binding class is instantiated
- **THEN** all C API functions (init, is_loaded, free, synthesize, synthesize_with_voice, set_language, get_audio, get_audio_length, get_sample_rate, get_error) are available as Dart methods
