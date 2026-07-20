## MODIFIED Requirements

### Requirement: piper-plus shared library build
The system SHALL include the piper-plus fork (https://github.com/endo5501/piper-plus) as a git submodule at `third_party/piper-plus/` and build it as a shared library (`.dylib` on macOS, `.dll` on Windows). The CMakeLists.txt SHALL include a `PIPER_TTS_BUILD_SHARED` option that, when enabled, builds a shared library target `piper_tts_ffi` from `src/cpp/piper_tts_c_api.cpp`. All dependencies (fmt, spdlog, ONNX Runtime, OpenJTalk) SHALL be statically linked into the shared library except ONNX Runtime which SHALL be dynamically linked.

On macOS, `scripts/build_piper_macos.sh` SHALL place exactly one ONNX Runtime shared library at `macos/Frameworks/libonnxruntime.dylib`, with its install name rewritten to `@rpath/libonnxruntime.dylib`. The script SHALL NOT copy version-suffixed variants (`libonnxruntime.<version>.dylib`) into `macos/Frameworks/`, because `libpiper_tts_ffi.dylib` links against the unversioned `@rpath/libonnxruntime.dylib` only, and every file under `macos/Frameworks/` is embedded into the app bundle. A version-suffixed copy is a byte-identical duplicate that adds ~21MB of dead weight to the bundle.

#### Scenario: Build shared library on macOS
- **WHEN** `scripts/build_piper_macos.sh` is executed on macOS
- **THEN** `libpiper_tts_ffi.dylib` and `libonnxruntime.dylib` are compiled and placed in `macos/Frameworks/`

#### Scenario: No version-suffixed ONNX Runtime copy is produced
- **WHEN** `scripts/build_piper_macos.sh` completes on macOS
- **THEN** `macos/Frameworks/` contains no file matching `libonnxruntime.*.dylib` other than `libonnxruntime.dylib`

#### Scenario: piper links against the unversioned ONNX Runtime
- **WHEN** `otool -L macos/Frameworks/libpiper_tts_ffi.dylib` is executed
- **THEN** the output references `@rpath/libonnxruntime.dylib` and no version-suffixed ONNX Runtime path

#### Scenario: Build shared library on Windows
- **WHEN** `scripts/build_piper_windows.bat` is executed on Windows with MSVC
- **THEN** `piper_tts_ffi.dll` and `onnxruntime.dll` are compiled and placed in the build output directory

#### Scenario: CPU-only build without GPU acceleration
- **WHEN** the shared library is built with default options
- **THEN** ONNX Runtime uses CPU execution provider only, without CUDA/CoreML/DirectML
