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
The C API SHALL provide functions to generate audio from text. The synthesis function SHALL accept text input and return audio data as a float array at 24kHz sample rate. A voice cloning variant SHALL accept an additional reference audio file path. The reference audio file SHALL support WAV format (PCM 16-bit, PCM 32-bit, IEEE Float 32-bit) and MP3 format. The `load_audio_file` function SHALL detect the file format by extension and decode accordingly.

#### Scenario: Synthesize text without voice cloning
- **WHEN** `qwen3_tts_synthesize` is called with Japanese text on a loaded context
- **THEN** audio data is generated and accessible via `qwen3_tts_get_audio`, `qwen3_tts_get_audio_length`, and `qwen3_tts_get_sample_rate` (24000)

#### Scenario: Synthesize text with voice cloning using WAV reference
- **WHEN** `qwen3_tts_synthesize_with_voice` is called with Japanese text and a valid reference WAV file path
- **THEN** audio data is generated using the reference voice characteristics

#### Scenario: Synthesize text with voice cloning using MP3 reference
- **WHEN** `qwen3_tts_synthesize_with_voice` is called with Japanese text and a valid reference MP3 file path
- **THEN** the MP3 file is decoded to PCM samples, resampled to 24kHz if needed, and audio data is generated using the reference voice characteristics

#### Scenario: Synthesize with invalid reference audio file
- **WHEN** `qwen3_tts_synthesize_with_voice` is called with a non-existent audio file path
- **THEN** synthesis fails and `qwen3_tts_get_error` returns a descriptive error message

#### Scenario: Synthesize with unsupported audio format
- **WHEN** `qwen3_tts_synthesize_with_voice` is called with a file that has an unsupported extension (e.g., `.ogg`)
- **THEN** synthesis fails and `qwen3_tts_get_error` returns an error message indicating the format is unsupported

#### Scenario: Retrieve synthesis error
- **WHEN** synthesis fails for any reason
- **THEN** `qwen3_tts_get_error` returns a non-empty error string describing the failure

### Requirement: MP3 audio decoding via minimp3
The `load_audio_file` function SHALL support MP3 file decoding using the minimp3 library. MP3 files SHALL be decoded to PCM float samples normalized to the range [-1.0, 1.0]. Multi-channel MP3 files SHALL be mixed down to mono. The decoded sample rate SHALL be preserved and resampled to 24kHz by the existing resampling logic if needed.

#### Scenario: Load mono MP3 file
- **WHEN** `load_audio_file` is called with a path to a mono MP3 file at 44100Hz
- **THEN** the file is decoded to float samples, and the sample rate is reported as 44100

#### Scenario: Load stereo MP3 file
- **WHEN** `load_audio_file` is called with a path to a stereo MP3 file
- **THEN** the stereo channels are mixed down to mono float samples

#### Scenario: Load corrupt MP3 file
- **WHEN** `load_audio_file` is called with a path to a corrupt or invalid MP3 file
- **THEN** the function returns false and an error message is printed to stderr

#### Scenario: File format detection by extension
- **WHEN** `load_audio_file` is called with a file path
- **THEN** the function determines the format by the file extension (case-insensitive): `.wav` for WAV decoding, `.mp3` for MP3 decoding

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

### Requirement: Unicode file path support on Windows
The `load_wav_file`, `load_mp3_file`, and `save_audio_file` functions SHALL correctly handle file paths containing non-ASCII characters (e.g., Japanese, Chinese, Korean) on Windows. On Windows, UTF-8 encoded file paths SHALL be converted to UTF-16 (wchar_t) using `MultiByteToWideChar(CP_UTF8, ...)` before opening files. WAV file operations SHALL use `_wfopen()` instead of `fopen()`. MP3 file operations SHALL use `mp3dec_load_w()` instead of `mp3dec_load()`. On non-Windows platforms, the existing `fopen()` and `mp3dec_load()` SHALL continue to be used unchanged.

#### Scenario: Load WAV file with Japanese filename on Windows
- **WHEN** `load_audio_file` is called with a UTF-8 encoded path containing Japanese characters (e.g., `C:/voices/青年1.wav`) on Windows
- **THEN** the file is opened successfully using `_wfopen()` with the UTF-16 converted path, and audio samples are returned

#### Scenario: Load MP3 file with Japanese filename on Windows
- **WHEN** `load_audio_file` is called with a UTF-8 encoded path containing Japanese characters (e.g., `C:/voices/ナレーター.mp3`) on Windows
- **THEN** the file is opened successfully using `mp3dec_load_w()` with the UTF-16 converted path, and audio samples are returned

#### Scenario: Save WAV file with Japanese filename on Windows
- **WHEN** `save_audio_file` is called with a UTF-8 encoded path containing Japanese characters on Windows
- **THEN** the file is created successfully using `_wfopen()` with the UTF-16 converted path

#### Scenario: ASCII filenames continue to work on Windows
- **WHEN** `load_audio_file` is called with an ASCII-only path (e.g., `C:/voices/seinen1.wav`) on Windows
- **THEN** the file is opened successfully (no regression)

#### Scenario: Non-Windows platforms unaffected
- **WHEN** `load_audio_file` or `save_audio_file` is called on macOS or Linux
- **THEN** the existing `fopen()` and `mp3dec_load()` functions are used without any UTF-16 conversion
