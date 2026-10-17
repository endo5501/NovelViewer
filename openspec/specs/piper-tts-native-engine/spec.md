## Purpose

Native piper-plus TTS engine integration: shared library build (macOS / Windows MSVC, statically linked deps + dynamic ONNX Runtime; the iOS framework is specified by `piper-ios-build`), C API for context lifecycle, synthesis (float32 PCM), tunable parameters (length/noise scales), and Dart FFI bindings + `PiperTtsEngine` wrapper conforming to the common TTS engine interface.

## Requirements

### Requirement: piper-plus shared library build
The system SHALL include upstream piper-plus (https://github.com/ayutaz/piper-plus) as a git submodule at `third_party/piper-plus/`, pinned to the release tag `v2.0.2`. The submodule SHALL NOT point to a fork carrying project-specific native code. The system SHALL build upstream's official C API shared library by enabling upstream's `PIPER_PLUS_BUILD_SHARED` CMake option, producing `libpiper_plus.dylib` on macOS and `piper_plus.dll` on Windows. All dependencies (fmt, spdlog, OpenJTalk) SHALL be statically linked into the shared library except ONNX Runtime, which SHALL be dynamically linked.

The iOS build is the one exception to building the pinned tree unmodified. Upstream v2.0.2 replaces OpenJTalk with stubs on iOS, so Japanese text yields no phonemes there. The iOS build SHALL apply the project-maintained patches under `patches/piper-plus/` to an extracted copy of the submodule tree, as `piper-ios-build` specifies. It SHALL NOT modify the submodule's working tree, and SHALL NOT repoint the submodule. The macOS and Windows builds SHALL NOT apply these patches.

On macOS, `scripts/build_piper_macos.sh` SHALL place exactly one piper-plus library at `macos/Frameworks/libpiper_plus.dylib` with its install name rewritten to `@rpath/libpiper_plus.dylib`, and exactly one ONNX Runtime library at `macos/Frameworks/libonnxruntime.dylib` with its install name rewritten to `@rpath/libonnxruntime.dylib`. The script SHALL NOT copy version-suffixed variants (`libpiper_plus.<version>.dylib`, `libonnxruntime.<version>.dylib`) into `macos/Frameworks/`, because every file under `macos/Frameworks/` is embedded into the app bundle and a version-suffixed copy is a byte-identical duplicate that only bloats the bundle.

#### Scenario: Build shared library on macOS
- **WHEN** `scripts/build_piper_macos.sh` is executed on macOS
- **THEN** `libpiper_plus.dylib` and `libonnxruntime.dylib` are compiled and placed in `macos/Frameworks/`

#### Scenario: No version-suffixed ONNX Runtime copy is produced
- **WHEN** `scripts/build_piper_macos.sh` completes on macOS
- **THEN** `macos/Frameworks/` contains no file matching `libpiper_plus.*.dylib` other than `libpiper_plus.dylib`, and no file matching `libonnxruntime.*.dylib` other than `libonnxruntime.dylib`

#### Scenario: piper links against the unversioned ONNX Runtime
- **WHEN** `otool -L macos/Frameworks/libpiper_plus.dylib` is executed
- **THEN** the output shows the library's own install name as `@rpath/libpiper_plus.dylib`, references `@rpath/libonnxruntime.dylib`, and references no version-suffixed ONNX Runtime path

#### Scenario: Build shared library on Windows
- **WHEN** `scripts/build_piper_windows.bat` is executed on Windows with MSVC
- **THEN** `piper_plus.dll` and `onnxruntime.dll` are compiled and placed in the build output directory

#### Scenario: CPU-only build without GPU acceleration
- **WHEN** the shared library is built with default options
- **THEN** ONNX Runtime uses CPU execution provider only, without CUDA/CoreML/DirectML

#### Scenario: Submodule tracks the upstream release tag
- **WHEN** `.gitmodules` and the `third_party/piper-plus` submodule commit are inspected
- **THEN** the submodule URL is `https://github.com/ayutaz/piper-plus.git` and the pinned commit is the one tagged `v2.0.2`

#### Scenario: Desktop builds use the unpatched tree
- **WHEN** `scripts/build_piper_macos.sh` or `scripts/build_piper_windows.bat` is inspected
- **THEN** neither reads `patches/piper-plus/`, and both build directly from `third_party/piper-plus`

### Requirement: Dart FFI bindings for piper-plus
The system SHALL provide a `PiperNativeBindings` class that loads `libpiper_plus.dylib` (macOS), `piper_plus.dll` (Windows) or `piper_plus.framework/piper_plus` (iOS) and exposes the subset of upstream's official C API (`piper_plus.h`) that the app uses as Dart members: engine creation and release, default synthesis options, synthesis, audio buffer release, sample rate, language-name lookup, phonemization, last-error retrieval, and API version retrieval. The C structs `PiperPlusConfig`, `PiperPlusSynthOptions` and `PiperPlusPhonemeResult` SHALL be represented with a memory layout identical to `piper_plus.h`, including their reserved fields.

#### Scenario: Load shared library on macOS
- **WHEN** `PiperNativeBindings.open()` is called on macOS
- **THEN** `libpiper_plus.dylib` is loaded from the app's Frameworks directory

#### Scenario: Load shared library on Windows
- **WHEN** `PiperNativeBindings.open()` is called on Windows
- **THEN** `piper_plus.dll` is loaded from the executable directory

#### Scenario: Load framework on iOS
- **WHEN** `PiperNativeBindings.open()` is called on iOS
- **THEN** `piper_plus.framework/piper_plus` is loaded from the app's `Frameworks` directory, with ONNX Runtime linked into it rather than loaded as a separate library

### Requirement: Dart TTS engine wrapper for piper-plus
The system SHALL provide a `PiperTtsEngine` class that wraps `PiperNativeBindings` with a Dart-friendly API. The class SHALL provide `loadModel(modelPath, dicDir)`, `synthesize(text)` returning `TtsSynthesisResult`, `setLengthScale(value)`, `setNoiseScale(value)`, `setNoiseW(value)`, `isLoaded`, and `dispose()`. The `synthesize()` method SHALL return the same `TtsSynthesisResult` type used by the other TTS engines, with audio as float32 PCM in the range [-1.0, 1.0] and the model's sample rate.

`loadModel` SHALL load the `.onnx` model at `modelPath`, use `modelPath + ".json"` as its config, and use `dicDir` as the OpenJTalk dictionary directory. If loading fails, `loadModel` SHALL throw `TtsEngineException` carrying the native error message, and `isLoaded` SHALL be false.

Synthesis parameters set through `setLengthScale` / `setNoiseScale` / `setNoiseW` SHALL apply to every subsequent `synthesize()` call until changed or until the engine is disposed. Parameters that were never set SHALL use upstream's defaults for those fields.

#### Scenario: Synthesize returns TtsSynthesisResult
- **WHEN** `piperEngine.synthesize("テスト")` is called on a loaded engine
- **THEN** a `TtsSynthesisResult` with `audio` (Float32List, non-empty) and `sampleRate` (int) is returned

#### Scenario: Load failure surfaces the native error
- **WHEN** `piperEngine.loadModel("nonexistent.onnx", dicDir: "models/piper/open_jtalk_dic")` is called
- **THEN** a `TtsEngineException` whose message contains the native error text is thrown, and `isLoaded` is false

#### Scenario: Synthesize without a loaded model
- **WHEN** `synthesize("text")` is called before `loadModel` succeeds
- **THEN** a `TtsEngineException` is thrown and no native synthesis is attempted

#### Scenario: Synthesis failure surfaces the native error
- **WHEN** native synthesis returns an error status
- **THEN** `synthesize()` throws a `TtsEngineException` whose message contains the native error text

#### Scenario: Parameters persist across multiple syntheses
- **WHEN** `setLengthScale(1.5)` is called once, then `synthesize()` is called twice
- **THEN** both synthesis calls pass length_scale=1.5 to the native library

#### Scenario: Engine disposal frees native resources
- **WHEN** `piperEngine.dispose()` is called
- **THEN** the native engine is freed and `isLoaded` returns false

### Requirement: Native audio buffer ownership
The audio buffer returned by native synthesis is owned by the caller. `PiperTtsEngine.synthesize()` SHALL copy the samples into Dart-managed memory and then release the native buffer exactly once through the C API's audio-release function. The buffer SHALL also be released when synthesis returns a buffer but the result is rejected (for example, zero samples).

#### Scenario: Buffer released after successful synthesis
- **WHEN** `synthesize()` completes successfully
- **THEN** the returned `TtsSynthesisResult.audio` is a copy independent of native memory, and the native buffer has been released exactly once

#### Scenario: Buffer released when the result is empty
- **WHEN** native synthesis reports success with a non-null buffer but zero samples
- **THEN** `synthesize()` throws `TtsEngineException` and the native buffer has been released exactly once

### Requirement: Piper synthesis language is Japanese
Piper synthesis SHALL request Japanese explicitly instead of relying on automatic language detection, which preserves the v1.8 behavior of always synthesizing with the model's Japanese language id. When the model's language map contains `ja`, every synthesis SHALL pass that language id. When the model has no `ja` entry (for example, a single-language model), synthesis SHALL fall back to automatic language detection.

#### Scenario: Multilingual model with a Japanese entry
- **WHEN** a model whose `language_id_map` maps `ja` to 0 is loaded and `synthesize()` is called
- **THEN** the synthesis options pass language id 0

#### Scenario: Model without a Japanese entry
- **WHEN** a model whose language map has no `ja` entry is loaded and `synthesize()` is called
- **THEN** the synthesis options pass language id -1 (automatic detection)

### Requirement: Native C API version check
On load, the engine SHALL verify that the native library reports C API version 1 (`PIPER_PLUS_API_VERSION` of upstream v2.0.2). If the reported version differs, loading SHALL fail with a `TtsEngineException` that states the expected and actual versions, so that a mismatched library is detected at load time and is not a memory-layout error during synthesis.

#### Scenario: Matching API version
- **WHEN** the native library reports API version 1
- **THEN** model loading proceeds normally

#### Scenario: Mismatched API version
- **WHEN** the native library reports an API version other than 1
- **THEN** `loadModel` throws `TtsEngineException` naming the expected version 1 and the actual version, and no native engine is created

### Requirement: Kanji-only Japanese text is phonemized as Japanese
The engine SHALL make upstream's script-based language detection treat CJK ideographs as Japanese, so that a sentence with no kana (for example 「多分。」 or 「父様。」) is phonemized with the Japanese phonemizer instead of the Chinese one. The engine SHALL do this by giving the native engine a model config derived from the downloaded `<model>.onnx.json` with `zh` removed from `language_id_map`, without changing any other language id. When the model's `language_id_map` does not contain both `ja` and `zh`, the engine SHALL use the downloaded config unchanged. The downloaded config file itself SHALL NOT be modified. If the derived config cannot be written (for example, a full disk), the engine SHALL load the downloaded config instead of failing, so Piper stays usable without the kanji-only improvement.

Rationale: upstream piper-plus classifies CJK ideographs as `zh` whenever the text contains no kana and the model knows both `ja` and `zh`, regardless of the requested language. The bundled app ships no pinyin dictionary, so such sentences produced no speakable phonemes (silence on v1.8, a hard synthesis error on v2.0.2).

#### Scenario: Derived config drops only zh
- **WHEN** a model whose `language_id_map` is `{ja: 0, en: 1, zh: 2, es: 3, fr: 4, pt: 5}` is loaded
- **THEN** the native engine is created with a config whose `language_id_map` is `{ja: 0, en: 1, es: 3, fr: 4, pt: 5}` and whose other fields equal the downloaded config, and the downloaded `<model>.onnx.json` is unchanged

#### Scenario: Derived config cannot be written
- **WHEN** writing `<model>.onnx.ja.json` fails while loading a model whose `language_id_map` has both `ja` and `zh`
- **THEN** the model loads with the downloaded `<model>.onnx.json` and no exception is thrown

#### Scenario: Config without both ja and zh is used as-is
- **WHEN** a model whose `language_id_map` lacks `zh` is loaded
- **THEN** the native engine is created with the downloaded `<model>.onnx.json` path

#### Scenario: Kanji-only sentence is spoken
- **WHEN** 「多分。」 is synthesized with the pinned model and the bundled native library
- **THEN** synthesis succeeds with Japanese phonemes (`t a [ b u N` …) instead of failing or producing only silence

### Requirement: Unspeakable text yields silence instead of an error
When a text produces no phoneme that exists in the model's `phoneme_id_map` (for example a symbol-only line such as `---`, or English-only text while no English dictionary is bundled), `PiperTtsEngine.synthesize()` SHALL NOT run native synthesis and SHALL return 0.2 seconds of silence at the model's sample rate instead of throwing. This keeps the v1.8 behavior, where such text produced silence and playback continued, and prevents upstream v2.0.2 from running inference on an empty id sequence (`Invalid input shape: {0}`), which stopped playback.

#### Scenario: Symbol-only text
- **WHEN** `synthesize("---")` is called on a loaded engine
- **THEN** a `TtsSynthesisResult` of 0.2 s of zero samples at the model's sample rate is returned and native synthesis is not called

#### Scenario: Text whose phonemes are all unknown to the model
- **WHEN** the native phonemizer returns only phonemes absent from `phoneme_id_map` (for example `.`)
- **THEN** 0.2 s of silence is returned and native synthesis is not called

#### Scenario: Speakable text is synthesized normally
- **WHEN** the native phonemizer returns at least one phoneme present in `phoneme_id_map`
- **THEN** native synthesis runs and its audio is returned

### Requirement: A missing native library is reported as such
When the piper-plus native library cannot be opened, opening the bindings SHALL fail with a `TtsEngineException` whose message names the library that could not be loaded and says how to obtain it, instead of letting the platform's dynamic-loader error propagate unexplained. On iOS the message SHALL name `piper_plus.framework` and `scripts/build_piper_ios.sh`, because the framework is built separately and is not tracked by Git, so a checkout that skipped that step builds an app without it. The loader's own error text SHALL be kept in the message, after the explanation, for diagnosis.

#### Scenario: The library is absent on iOS
- **WHEN** `PiperNativeBindings.open()` is called on iOS in an app built without `piper_plus.framework`
- **THEN** a `TtsEngineException` is thrown whose message names `piper_plus.framework` and `scripts/build_piper_ios.sh`, followed by the loader's error text

#### Scenario: The library is absent on desktop
- **WHEN** `PiperNativeBindings.open()` is called on macOS or Windows and the library file cannot be loaded
- **THEN** a `TtsEngineException` is thrown whose message names the library file and the build script for that platform

#### Scenario: A present library opens as before
- **WHEN** `PiperNativeBindings.open()` is called and the library loads
- **THEN** the bindings are returned and no exception is thrown
