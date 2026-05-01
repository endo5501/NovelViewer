## Purpose

Native piper-plus TTS engine integration: shared library build (macOS / Windows MSVC, statically linked deps + dynamic ONNX Runtime), C API for context lifecycle, synthesis (float32 PCM), tunable parameters (length/noise scales), and Dart FFI bindings + `PiperTtsEngine` wrapper conforming to the common TTS engine interface.

## Requirements

### Requirement: piper-plus shared library build
The system SHALL include the piper-plus fork (https://github.com/endo5501/piper-plus) as a git submodule at `third_party/piper-plus/` and build it as a shared library (`.dylib` on macOS, `.dll` on Windows). The CMakeLists.txt SHALL include a `PIPER_TTS_BUILD_SHARED` option that, when enabled, builds a shared library target `piper_tts_ffi` from `src/cpp/piper_tts_c_api.cpp`. All dependencies (fmt, spdlog, ONNX Runtime, OpenJTalk) SHALL be statically linked into the shared library except ONNX Runtime which SHALL be dynamically linked.

#### Scenario: Build shared library on macOS
- **WHEN** `scripts/build_piper_macos.sh` is executed on macOS
- **THEN** `libpiper_tts_ffi.dylib` and `libonnxruntime.dylib` are compiled and placed in `macos/Frameworks/`

#### Scenario: Build shared library on Windows
- **WHEN** `scripts/build_piper_windows.bat` is executed on Windows with MSVC
- **THEN** `piper_tts_ffi.dll` and `onnxruntime.dll` are compiled and placed in the build output directory

#### Scenario: CPU-only build without GPU acceleration
- **WHEN** the shared library is built with default options
- **THEN** ONNX Runtime uses CPU execution provider only, without CUDA/CoreML/DirectML

### Requirement: C API for piper-plus lifecycle
The shared library SHALL expose a C API via `piper_tts_c_api.h` with an opaque context type `piper_tts_ctx`. The `piper_tts_init(model_path, dic_dir)` function SHALL initialize the ONNX Runtime environment, load the voice model from `model_path` (`.onnx` file) and its config from `model_path + ".json"`, and set the OpenJTalk dictionary path to `dic_dir`. The function SHALL return a valid context pointer on success or NULL on failure. The `piper_tts_free(ctx)` function SHALL release all resources. The `piper_tts_is_loaded(ctx)` function SHALL return non-zero if the model is loaded.

#### Scenario: Initialize with valid model and dictionary
- **WHEN** `piper_tts_init("models/piper/ja_JP-tsukuyomi-chan-medium.onnx", "models/piper/open_jtalk_dic")` is called
- **THEN** the function returns a non-NULL context with `piper_tts_is_loaded()` returning non-zero

#### Scenario: Initialize with invalid model path
- **WHEN** `piper_tts_init("nonexistent.onnx", "models/piper/open_jtalk_dic")` is called
- **THEN** the function returns a non-NULL context with `piper_tts_is_loaded()` returning 0, and `piper_tts_get_error()` returns an error message

#### Scenario: Free context releases resources
- **WHEN** `piper_tts_free(ctx)` is called on a valid context
- **THEN** all ONNX Runtime sessions, voice data, and allocated memory are released

### Requirement: C API for synthesis
The `piper_tts_synthesize(ctx, text)` function SHALL synthesize speech from the given text and store the result internally. The output audio SHALL be float32 PCM samples in the range [-1.0, 1.0], converted from piper-plus's native int16 output. The function SHALL return 0 on success and -1 on failure.

#### Scenario: Synthesize Japanese text
- **WHEN** `piper_tts_synthesize(ctx, "こんにちは")` is called with a loaded Japanese model
- **THEN** the function returns 0, and `piper_tts_get_audio()` returns a non-NULL float pointer with `piper_tts_get_audio_length()` > 0

#### Scenario: Synthesize with unloaded model
- **WHEN** `piper_tts_synthesize(ctx, "text")` is called on an unloaded context
- **THEN** the function returns -1 and `piper_tts_get_error()` contains an error message

#### Scenario: Audio format is float32 normalized
- **WHEN** synthesis completes successfully
- **THEN** `piper_tts_get_audio()` returns float32 samples in the range [-1.0, 1.0] and `piper_tts_get_sample_rate()` returns the model's sample rate (typically 22050)

### Requirement: C API for synthesis parameters
The C API SHALL provide functions to adjust piper-plus synthesis parameters: `piper_tts_set_length_scale(ctx, value)` for speech speed, `piper_tts_set_noise_scale(ctx, value)` for expressiveness, and `piper_tts_set_noise_w(ctx, value)` for phoneme duration variation. Each function SHALL return 0 on success. The parameters SHALL take effect on the next call to `piper_tts_synthesize()`.

#### Scenario: Set length scale affects speech speed
- **WHEN** `piper_tts_set_length_scale(ctx, 0.8)` is called followed by synthesis
- **THEN** the generated audio is shorter (faster) than with the default length scale of 1.0

#### Scenario: Set noise scale affects expressiveness
- **WHEN** `piper_tts_set_noise_scale(ctx, 0.3)` is called followed by synthesis
- **THEN** the generated audio has less variation than with the default noise scale of 0.667

#### Scenario: Parameters persist across multiple syntheses
- **WHEN** `piper_tts_set_length_scale(ctx, 1.5)` is called once, then synthesis is called twice
- **THEN** both synthesis calls use length_scale=1.5

### Requirement: Dart FFI bindings for piper-plus
The system SHALL provide `PiperNativeBindings` class that loads `libpiper_tts_ffi.dylib` (macOS) or `piper_tts_ffi.dll` (Windows) and exposes all C API functions as Dart methods. The class SHALL follow the same pattern as the existing `TtsNativeBindings`.

#### Scenario: Load shared library on macOS
- **WHEN** `PiperNativeBindings.open()` is called on macOS
- **THEN** `libpiper_tts_ffi.dylib` is loaded from the app's Frameworks directory

#### Scenario: Load shared library on Windows
- **WHEN** `PiperNativeBindings.open()` is called on Windows
- **THEN** `piper_tts_ffi.dll` is loaded from the executable directory

### Requirement: Dart TTS engine wrapper for piper-plus
The system SHALL provide `PiperTtsEngine` class that wraps `PiperNativeBindings` with a Dart-friendly API. The class SHALL provide `loadModel(modelPath, dicDir)`, `synthesize(text)` returning `TtsSynthesisResult`, `setLengthScale(value)`, `setNoiseScale(value)`, `setNoiseW(value)`, and `dispose()` methods. The `synthesize()` method SHALL return the same `TtsSynthesisResult` type used by the existing `TtsEngine`.

#### Scenario: Synthesize returns TtsSynthesisResult
- **WHEN** `piperEngine.synthesize("テスト")` is called
- **THEN** a `TtsSynthesisResult` with `audio` (Float32List) and `sampleRate` (int) is returned

#### Scenario: Engine disposal frees native resources
- **WHEN** `piperEngine.dispose()` is called
- **THEN** the native context is freed and `isLoaded` returns false
