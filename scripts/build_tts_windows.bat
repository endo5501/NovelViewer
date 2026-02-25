@echo off
setlocal enabledelayedexpansion

set SCRIPT_DIR=%~dp0
set PROJECT_ROOT=%SCRIPT_DIR%..
set TTS_DIR=%PROJECT_ROOT%\third_party\qwen3-tts.cpp
set GGML_DIR=%TTS_DIR%\ggml

echo === Building GGML (CPU + Vulkan backend) ===
if not exist "%GGML_DIR%\build" mkdir "%GGML_DIR%\build"
cmake -S "%GGML_DIR%" -B "%GGML_DIR%\build" ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DBUILD_SHARED_LIBS=OFF ^
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON ^
    -DGGML_VULKAN=ON
cmake --build "%GGML_DIR%\build" --config Release

echo === Building qwen3_tts_ffi shared library ===
if not exist "%TTS_DIR%\build" mkdir "%TTS_DIR%\build"
cmake -S "%TTS_DIR%" -B "%TTS_DIR%\build" ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DQWEN3_TTS_BUILD_SHARED=ON ^
    -DQWEN3_TTS_COREML=OFF ^
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON
cmake --build "%TTS_DIR%\build" --config Release --target qwen3_tts_ffi

echo === Copying DLL to build output ===
set DLL_SRC=%TTS_DIR%\build\Release\qwen3_tts_ffi.dll
if not exist "%DLL_SRC%" set DLL_SRC=%TTS_DIR%\build\qwen3_tts_ffi.dll

set RUNNER_DIR=%PROJECT_ROOT%\build\windows\x64\runner\Release
if not exist "%RUNNER_DIR%" mkdir "%RUNNER_DIR%"
copy "%DLL_SRC%" "%RUNNER_DIR%\" /Y

echo === Done ===
echo DLL copied to: %RUNNER_DIR%\qwen3_tts_ffi.dll
