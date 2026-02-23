## ADDED Requirements

### Requirement: TTS shared library build
The system SHALL include qwen3-tts.cpp as a git submodule and build it as a shared library (`.dylib` on macOS, `.dll` on Windows). The shared library SHALL expose a C API that wraps the C++ `Qwen3TTS` class. The GGML dependency SHALL be built as part of the qwen3-tts.cpp submodule build process. The CMakeLists.txt SHALL include MSVC-specific compiler settings to ensure correct compilation on Windows: `/utf-8` for UTF-8 source file encoding, `_USE_MATH_DEFINES` for POSIX math constants, and `_CRT_SECURE_NO_WARNINGS` for CRT deprecation warnings. The source code SHALL include Windows platform support for process memory tracking using `GetProcessMemoryInfo` from the Windows API, with `NOMINMAX` defined to prevent `min`/`max` macro conflicts.

#### Scenario: Build shared library on macOS
- **WHEN** the Flutter app is built for macOS
- **THEN** the qwen3-tts.cpp shared library (`libqwen3_tts_ffi.dylib`) is compiled with Metal support and bundled in the app's Frameworks directory

#### Scenario: Build shared library on Windows
- **WHEN** `scripts/build_tts_windows.bat` is executed on a Windows environment with MSVC
- **THEN** the qwen3-tts.cpp shared library (`qwen3_tts_ffi.dll`) is compiled without errors and placed in `build/windows/x64/runner/Release/`

#### Scenario: MSVC compiles UTF-8 source files correctly
- **WHEN** `text_tokenizer.cpp` containing UTF-8 encoded Unicode string literals is compiled with MSVC
- **THEN** the compilation succeeds without C3688 or C4819 errors

#### Scenario: MSVC resolves POSIX math constants
- **WHEN** `audio_tokenizer_encoder.cpp` using `M_PI` is compiled with MSVC
- **THEN** the compilation succeeds without C2065 errors for `M_PI`

#### Scenario: Windows process memory tracking
- **WHEN** `qwen3_tts.cpp` is compiled on Windows with MSVC
- **THEN** the process memory snapshot function uses `GetProcessMemoryInfo` from `psapi.h` instead of POSIX `getrusage`, and compiles without C1083 errors for `sys/resource.h`

#### Scenario: No min/max macro conflicts on Windows
- **WHEN** `qwen3_tts.cpp` includes `<windows.h>` and uses `std::min`/`std::max`
- **THEN** the compilation succeeds without C2589 errors due to `NOMINMAX` being defined before the Windows header include

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
