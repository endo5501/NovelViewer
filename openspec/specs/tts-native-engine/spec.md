## ADDED Requirements

### Requirement: TTS shared library build
The system SHALL include qwen3-tts.cpp as a git submodule and build it as a shared library (`.dylib` on macOS, `.dll` on Windows). The shared library SHALL expose a C API that wraps the C++ `Qwen3TTS` class. The GGML dependency SHALL be built as part of the qwen3-tts.cpp submodule build process and SHALL use ggml v0.9.11 or later. The CMakeLists.txt SHALL include MSVC-specific compiler settings to ensure correct compilation on Windows: `/utf-8` for UTF-8 source file encoding, `_USE_MATH_DEFINES` for POSIX math constants, and `_CRT_SECURE_NO_WARNINGS` for CRT deprecation warnings. The source code SHALL include Windows platform support for process memory tracking using `GetProcessMemoryInfo` from the Windows API, with `NOMINMAX` defined to prevent `min`/`max` macro conflicts.

#### Scenario: Build shared library on macOS
- **WHEN** the Flutter app is built for macOS
- **THEN** the qwen3-tts.cpp shared library (`libqwen3_tts_ffi.dylib`) is compiled with Metal support and bundled in the app's Frameworks directory

#### Scenario: Build shared library on Windows
- **WHEN** `scripts/build_tts_windows.bat` is executed on a Windows environment with MSVC
- **THEN** the qwen3-tts.cpp shared library (`qwen3_tts_ffi.dll`) is compiled without errors and placed in `build/windows/x64/runner/Release/`

#### Scenario: GGML version is v0.9.11
- **WHEN** the ggml submodule within qwen3-tts.cpp is checked
- **THEN** the ggml version SHALL be v0.9.11 as reported by `GGML_VERSION_MAJOR=0`, `GGML_VERSION_MINOR=9`, `GGML_VERSION_PATCH=11` in ggml's CMakeLists.txt

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
The C API SHALL provide functions to initialize and release TTS model resources. Initialization SHALL accept a model directory path and a thread count. The model directory SHALL contain the required GGUF files (transformer and vocoder). The model file detection SHALL be dynamic: the system SHALL search the model directory for files matching `qwen3-tts-*.gguf` (excluding files containing `tokenizer`) for the TTS model, and `qwen3-tts-tokenizer*.gguf` for the vocoder. The TTS model file SHALL be exactly one; if zero or multiple TTS model files are found, initialization SHALL fail with an error. The vocoder tokenizer model selection SHALL prefer the Q8_0 quantized file (`qwen3-tts-tokenizer-q8_0.gguf`) when it exists in the model directory, falling back to the F16 file (`qwen3-tts-tokenizer-f16.gguf`) otherwise. The `qwen3_tts_ctx` structure SHALL include a `std::atomic<bool> abort_flag` field initialized to `false`.

#### Scenario: Initialize TTS model successfully
- **WHEN** `qwen3_tts_init` is called with a valid model directory containing GGUF files and a thread count of 4
- **THEN** a non-null context pointer is returned and the model is loaded into memory with abort_flag initialized to false

#### Scenario: Initialize with 0.6B model
- **WHEN** `qwen3_tts_init` is called with a directory containing only `qwen3-tts-0.6b-f16.gguf` and `qwen3-tts-tokenizer-f16.gguf`
- **THEN** the 0.6B model is detected and loaded successfully

#### Scenario: Initialize with 1.7B model
- **WHEN** `qwen3_tts_init` is called with a directory containing only `qwen3-tts-1.7b-f16.gguf` and `qwen3-tts-tokenizer-f16.gguf`
- **THEN** the 1.7B model is detected and loaded successfully

#### Scenario: Multiple TTS model files in directory
- **WHEN** `qwen3_tts_init` is called with a directory containing both `qwen3-tts-0.6b-f16.gguf` and `qwen3-tts-1.7b-f16.gguf`
- **THEN** initialization SHALL fail and return a null pointer with an error indicating ambiguous model files

#### Scenario: Initialize TTS model with invalid path
- **WHEN** `qwen3_tts_init` is called with a directory that does not contain any matching GGUF files
- **THEN** a null pointer is returned

#### Scenario: Check model loaded state
- **WHEN** `qwen3_tts_is_loaded` is called on a successfully initialized context
- **THEN** true is returned

#### Scenario: Free model resources
- **WHEN** `qwen3_tts_free` is called on an initialized context
- **THEN** all model resources are released and the context pointer is invalidated

#### Scenario: Q8_0 tokenizer is preferred when available
- **WHEN** `qwen3_tts_init` is called with a directory containing both `qwen3-tts-tokenizer-q8_0.gguf` and `qwen3-tts-tokenizer-f16.gguf`
- **THEN** the Q8_0 tokenizer model is loaded

#### Scenario: F16 tokenizer is used as fallback
- **WHEN** `qwen3_tts_init` is called with a directory containing only `qwen3-tts-tokenizer-f16.gguf` (no Q8_0 file)
- **THEN** the F16 tokenizer model is loaded successfully

### Requirement: C API for text-to-speech synthesis
The C API SHALL provide functions to generate audio from text. The synthesis function SHALL accept text input and a maximum audio token count, and return audio data as a float array at 24kHz sample rate. A voice cloning variant SHALL accept an additional reference audio file path and a maximum audio token count. The reference audio file SHALL support WAV format (PCM 16-bit, PCM 32-bit, IEEE Float 32-bit) and MP3 format. The `load_audio_file` function SHALL detect the file format by extension and decode accordingly. Additionally, the C API SHALL provide a variant that accepts a pre-extracted speaker embedding directly, bypassing the audio encoder, along with a maximum audio token count. When `max_tokens` is 0 or negative, the C++ default (2048) SHALL be used.

#### Scenario: Synthesize text without voice cloning
- **WHEN** `qwen3_tts_synthesize` is called with Japanese text, a max_tokens value of 500, on a loaded context
- **THEN** audio data is generated with at most 500 audio frames and accessible via `qwen3_tts_get_audio`, `qwen3_tts_get_audio_length`, and `qwen3_tts_get_sample_rate` (24000)

#### Scenario: Synthesize text with voice cloning using WAV reference
- **WHEN** `qwen3_tts_synthesize_with_voice` is called with Japanese text, a valid reference WAV file path, and a max_tokens value of 800
- **THEN** audio data is generated with at most 800 audio frames using the reference voice characteristics

#### Scenario: Synthesize text with voice cloning using MP3 reference
- **WHEN** `qwen3_tts_synthesize_with_voice` is called with Japanese text, a valid reference MP3 file path, and a max_tokens value of 800
- **THEN** the MP3 file is decoded to PCM samples, resampled to 24kHz if needed, and audio data is generated using the reference voice characteristics

#### Scenario: Synthesize text with pre-extracted speaker embedding
- **WHEN** `qwen3_tts_synthesize_with_embedding` is called with Japanese text, a float32 embedding array matching the model's `hidden_size`, and a max_tokens value of 600
- **THEN** audio data is generated with at most 600 audio frames using the provided embedding without invoking the audio encoder

#### Scenario: Synthesize with invalid embedding size
- **WHEN** `qwen3_tts_synthesize_with_embedding` is called with an embedding array whose size does not match the model's `hidden_size` (e.g., 1024 for 0.6B, 2048 for 1.7B)
- **THEN** synthesis fails and `qwen3_tts_get_error` returns a descriptive error message including expected and actual sizes

#### Scenario: Synthesize with null embedding
- **WHEN** `qwen3_tts_synthesize_with_embedding` is called with a null embedding pointer
- **THEN** synthesis fails and `qwen3_tts_get_error` returns a descriptive error message

#### Scenario: Synthesize with invalid reference audio file
- **WHEN** `qwen3_tts_synthesize_with_voice` is called with a non-existent audio file path
- **THEN** synthesis fails and `qwen3_tts_get_error` returns a descriptive error message

#### Scenario: Synthesize with unsupported audio format
- **WHEN** `qwen3_tts_synthesize_with_voice` is called with a file that has an unsupported extension (e.g., `.ogg`)
- **THEN** synthesis fails and `qwen3_tts_get_error` returns an error message indicating the format is unsupported

#### Scenario: Retrieve synthesis error
- **WHEN** synthesis fails for any reason
- **THEN** `qwen3_tts_get_error` returns a non-empty error string describing the failure

#### Scenario: Synthesize with zero max_tokens uses default
- **WHEN** `qwen3_tts_synthesize` is called with max_tokens=0
- **THEN** the C++ default max_audio_tokens (2048) is used

#### Scenario: Synthesize with negative max_tokens uses default
- **WHEN** `qwen3_tts_synthesize` is called with max_tokens=-1
- **THEN** the C++ default max_audio_tokens (2048) is used

### Requirement: C API for speaker embedding extraction
The C API SHALL provide a function `qwen3_tts_extract_speaker_embedding` to extract a speaker embedding from a reference audio file without performing synthesis. The function SHALL accept a context pointer and a reference audio file path, and SHALL output a pointer to the extracted embedding data and its size (number of float elements). The caller SHALL free the returned embedding memory using `qwen3_tts_free_speaker_embedding`.

#### Scenario: Extract embedding from WAV file
- **WHEN** `qwen3_tts_extract_speaker_embedding` is called with a valid WAV reference audio file
- **THEN** the function returns 0 (success), and the output pointer contains float32 values representing the speaker embedding (dimension depends on model's encoder config)

#### Scenario: Extract embedding from MP3 file
- **WHEN** `qwen3_tts_extract_speaker_embedding` is called with a valid MP3 reference audio file
- **THEN** the function returns 0 (success), and the output pointer contains float32 values representing the speaker embedding

#### Scenario: Extract embedding from invalid file
- **WHEN** `qwen3_tts_extract_speaker_embedding` is called with a non-existent or invalid audio file
- **THEN** the function returns -1 (error) and `qwen3_tts_get_error` returns a descriptive error message

#### Scenario: Free extracted embedding memory
- **WHEN** `qwen3_tts_free_speaker_embedding` is called with a pointer returned by `qwen3_tts_extract_speaker_embedding`
- **THEN** the memory is freed without error

### Requirement: C API for speaker embedding file I/O
The C API SHALL provide functions to save and load speaker embeddings to/from binary files. `qwen3_tts_save_speaker_embedding` SHALL write a float32 array to a file in raw binary format. `qwen3_tts_load_speaker_embedding` SHALL read a binary file and return a pointer to the loaded float32 array and its size. The caller SHALL free loaded embedding memory using `qwen3_tts_free_speaker_embedding`.

#### Scenario: Save embedding to file
- **WHEN** `qwen3_tts_save_speaker_embedding` is called with a valid path and a 1024-element float32 array
- **THEN** the function writes 4096 bytes (1024 * sizeof(float)) to the specified path and returns 0

#### Scenario: Save embedding to invalid path
- **WHEN** `qwen3_tts_save_speaker_embedding` is called with a path in a non-existent directory
- **THEN** the function returns -1 (error)

#### Scenario: Load embedding from valid file
- **WHEN** `qwen3_tts_load_speaker_embedding` is called with a path to a valid 4096-byte embedding file
- **THEN** the function returns 0 (success), and the output pointer contains 1024 float32 values

#### Scenario: Load embedding from invalid file
- **WHEN** `qwen3_tts_load_speaker_embedding` is called with a path to a non-existent file
- **THEN** the function returns -1 (error)

#### Scenario: Load embedding from file with wrong size
- **WHEN** `qwen3_tts_load_speaker_embedding` is called with a path to a file whose size is not a multiple of sizeof(float)
- **THEN** the function returns -1 (error)

### Requirement: Dart FFI bindings for speaker embedding operations
The system SHALL provide Dart FFI bindings for the new C API functions: `qwen3_tts_extract_speaker_embedding`, `qwen3_tts_synthesize_with_embedding`, `qwen3_tts_save_speaker_embedding`, `qwen3_tts_load_speaker_embedding`, and `qwen3_tts_free_speaker_embedding`. All FFI calls SHALL be designed to run safely within a Dart Isolate.

#### Scenario: Call extract embedding via FFI
- **WHEN** the Dart FFI binding for `extractSpeakerEmbedding` is called with a valid reference audio path
- **THEN** the binding returns a pointer to float32 values representing the speaker embedding

#### Scenario: Call synthesize with embedding via FFI
- **WHEN** the Dart FFI binding for `synthesizeWithEmbedding` is called with text and a float32 embedding array
- **THEN** audio data is generated and accessible via `getAudio`, `getAudioLength`, and `getSampleRate`

#### Scenario: Call save/load embedding via FFI
- **WHEN** the Dart FFI bindings for `saveSpeakerEmbedding` and `loadSpeakerEmbedding` are called
- **THEN** embeddings are persisted to and loaded from binary files correctly

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
The system SHALL provide Dart FFI bindings that wrap the C API functions. The bindings SHALL load the shared library from the platform-appropriate location. All FFI calls SHALL be designed to run safely within a Dart Isolate. The bindings SHALL include `abort` and `resetAbort` functions that can be safely called from any Isolate.

#### Scenario: Load shared library on macOS
- **WHEN** the Dart FFI bindings are initialized on macOS
- **THEN** the shared library is loaded from the app bundle's Frameworks directory

#### Scenario: Load shared library on Windows
- **WHEN** the Dart FFI bindings are initialized on Windows
- **THEN** the shared library is loaded from the executable's directory

#### Scenario: FFI bindings expose all C API functions
- **WHEN** the Dart FFI binding class is instantiated
- **THEN** all C API functions (init, is_loaded, free, synthesize, synthesize_with_voice, set_language, get_audio, get_audio_length, get_sample_rate, get_error, abort, reset_abort) are available as Dart methods

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

### Requirement: 64-bit file seek for large GGUF files on Windows
`tts_transformer.cpp` の `load_tensor_data` 関数はテンソルデータを読み込む際に、Windows では `_fseeki64` を使用して GGUF ファイル内の 2GB 超のオフセットを正しく処理しなければならない。Windows 以外では `fseek` をそのまま使用する。これにより 1.7B モデル（ファイルサイズ ~3.86GB）を Windows 上で正しくロードできる。

#### Scenario: 1.7B model loads successfully on Windows
- **WHEN** `qwen3_tts_init` is called on Windows with a directory containing the 1.7B model (`qwen3-tts-1.7b-f16.gguf`, ~3.86GB)
- **THEN** a non-null context pointer is returned, and all tensor data is read without seek failure

#### Scenario: 0.6B model is unaffected on Windows
- **WHEN** `qwen3_tts_init` is called on Windows with a directory containing the 0.6B model (~1.4GB)
- **THEN** a non-null context pointer is returned as before (no regression)

#### Scenario: macOS behavior unchanged
- **WHEN** `qwen3_tts_init` is called on macOS with the 1.7B model
- **THEN** a non-null context pointer is returned (existing behavior retained)

### Requirement: Model load failure error output
`load_models()` 関数は、各コンポーネント（TTS transformer、vocoder）のロードに失敗した場合、エラーメッセージを stderr に出力しなければならない。これにより、Flutter 側で `qwen3_tts_init` が nullptr を返した際の原因をログから特定できるようになる。

#### Scenario: Transformer load failure is logged to stderr
- **WHEN** `qwen3_tts_init` fails because the TTS transformer model cannot be loaded
- **THEN** an error message including the failure reason is written to stderr before returning null

#### Scenario: Vocoder load failure is logged to stderr
- **WHEN** `qwen3_tts_init` fails because the vocoder model cannot be loaded
- **THEN** an error message including the failure reason is written to stderr before returning null

### Requirement: GPU-safe codebook normalization
AudioTokenizerDecoder の codebook 正規化処理は、バックエンドに依存しない安全なメモリアクセスパターンを使用しなければならない（MUST）。テンソルデータへのアクセスは `ggml_backend_tensor_get()` でホストメモリにダウンロードし、正規化計算をホスト上で実行した後、`ggml_backend_tensor_set()` で書き戻さなければならない（MUST）。`tensor->data` ポインタへの直接キャストによるアクセスは行ってはならない（MUST NOT）。

#### Scenario: Codebook normalization on Vulkan backend
- **WHEN** vocoder モデルが Vulkan バックエンド上にロードされる
- **THEN** codebook 正規化が `ggml_backend_tensor_get/set` を通じて実行され、セグメンテーションフォルトが発生しない

#### Scenario: Codebook normalization on CPU backend
- **WHEN** vocoder モデルが CPU バックエンド上にロードされる
- **THEN** codebook 正規化が従来と同じ結果を生成する（回帰なし）

#### Scenario: First and rest codebooks are all normalized
- **WHEN** vocoder モデルがロードされる
- **THEN** `vq_first_codebook` と15個の `vq_rest_codebook` の全てが usage テンソルの値で正規化される
