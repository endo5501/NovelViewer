## ADDED Requirements

### Requirement: TTS shared library build
The system SHALL include qwen3-tts.cpp as a git submodule and build it as a shared library (`.dylib` on macOS, `.dll` on Windows). The shared library SHALL expose a C API that wraps the C++ `Qwen3TTS` class. The GGML dependency SHALL be built as part of the qwen3-tts.cpp submodule build process.

#### Scenario: Build shared library on macOS
- **WHEN** the Flutter app is built for macOS
- **THEN** the qwen3-tts.cpp shared library (`libqwen3_tts_ffi.dylib`) is compiled with Metal support and bundled in the app's Frameworks directory

#### Scenario: Build shared library on Windows
- **WHEN** the Flutter app is built for Windows
- **THEN** the qwen3-tts.cpp shared library (`qwen3_tts_ffi.dll`) is compiled with CPU backend and placed alongside the executable

### Requirement: C API for model lifecycle
The C API SHALL provide functions to initialize and release TTS model resources. Initialization SHALL accept a model directory path and a thread count. The model directory SHALL contain the required GGUF files (transformer and vocoder).

#### Scenario: Initialize TTS model successfully
- **WHEN** `qwen3_tts_init` is called with a valid model directory containing GGUF files and a thread count of 4
- **THEN** a non-null context pointer is returned and the model is loaded into memory

#### Scenario: Initialize TTS model with invalid path
- **WHEN** `qwen3_tts_init` is called with a directory that does not contain the required GGUF files
- **THEN** a null pointer is returned

#### Scenario: Check model loaded state
- **WHEN** `qwen3_tts_is_loaded` is called on a successfully initialized context
- **THEN** true is returned

#### Scenario: Free model resources
- **WHEN** `qwen3_tts_free` is called on an initialized context
- **THEN** all model resources are released and the context pointer is invalidated

### Requirement: C API for text-to-speech synthesis
The C API SHALL provide functions to generate audio from text. The synthesis function SHALL accept text input and return audio data as a float array at 24kHz sample rate. A voice cloning variant SHALL accept an additional reference WAV file path.

#### Scenario: Synthesize text without voice cloning
- **WHEN** `qwen3_tts_synthesize` is called with Japanese text on a loaded context
- **THEN** audio data is generated and accessible via `qwen3_tts_get_audio`, `qwen3_tts_get_audio_length`, and `qwen3_tts_get_sample_rate` (24000)

#### Scenario: Synthesize text with voice cloning
- **WHEN** `qwen3_tts_synthesize_with_voice` is called with Japanese text and a valid reference WAV file path
- **THEN** audio data is generated using the reference voice characteristics

#### Scenario: Synthesize with invalid reference WAV
- **WHEN** `qwen3_tts_synthesize_with_voice` is called with a non-existent WAV file path
- **THEN** synthesis fails and `qwen3_tts_get_error` returns a descriptive error message

#### Scenario: Retrieve synthesis error
- **WHEN** synthesis fails for any reason
- **THEN** `qwen3_tts_get_error` returns a non-empty error string describing the failure

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
- **THEN** all C API functions (init, is_loaded, free, synthesize, synthesize_with_voice, get_audio, get_audio_length, get_sample_rate, get_error) are available as Dart methods
