@echo off
setlocal enabledelayedexpansion

set SCRIPT_DIR=%~dp0
set PROJECT_ROOT=%SCRIPT_DIR%..
set PIPER_DIR=%PROJECT_ROOT%\third_party\piper-plus

echo === Building piper_tts_ffi shared library (CPU only) ===
if not exist "%PIPER_DIR%\build" mkdir "%PIPER_DIR%\build"
cmake -S "%PIPER_DIR%" -B "%PIPER_DIR%\build" ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DPIPER_TTS_BUILD_SHARED=ON ^
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON
cmake --build "%PIPER_DIR%\build" --config Release --target piper_tts_ffi

echo === Copying DLLs to build output ===
set DLL_SRC=%PIPER_DIR%\build\Release\piper_tts_ffi.dll
if not exist "%DLL_SRC%" set DLL_SRC=%PIPER_DIR%\build\piper_tts_ffi.dll

set RUNNER_DIR=%PROJECT_ROOT%\build\windows\x64\runner\Release
if not exist "%RUNNER_DIR%" mkdir "%RUNNER_DIR%"
copy "%DLL_SRC%" "%RUNNER_DIR%\" /Y

REM Copy ONNX Runtime DLL
REM Windows cmake downloads to build/onnxruntime/onnxruntime-win-x64-<version>/lib/
set ORT_DLL=
for /f "delims=" %%F in ('dir /s /b "%PIPER_DIR%\build\onnxruntime.dll" 2^>nul') do set ORT_DLL=%%F
if defined ORT_DLL (
    copy "%ORT_DLL%" "%RUNNER_DIR%\" /Y
) else (
    echo ERROR: onnxruntime.dll not found in %PIPER_DIR%\build
    exit /b 1
)

echo === Done ===
echo DLLs copied to: %RUNNER_DIR%
