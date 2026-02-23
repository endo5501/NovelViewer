## MODIFIED Requirements

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
