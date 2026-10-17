## MODIFIED Requirements

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
- **THEN** `piper_plus.framework/piper_plus` is loaded from the app's `Frameworks` directory, and the `onnxruntime.framework` it depends on is resolved from the same directory
