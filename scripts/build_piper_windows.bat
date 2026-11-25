@echo off
setlocal enabledelayedexpansion

set SCRIPT_DIR=%~dp0
set PROJECT_ROOT=%SCRIPT_DIR%..
set PIPER_DIR=%PROJECT_ROOT%\third_party\piper-plus

echo === Preparing ONNX Runtime from NuGet ===
REM piper-plus's cmake downloads ONNX Runtime from GitHub Releases, which is no
REM longer reachable. With build\onnxruntime\onnxruntime.zip in place it skips
REM the download and extracts that zip instead.
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%fetch_onnxruntime_windows.ps1"
if errorlevel 1 (
    echo ERROR: failed to prepare ONNX Runtime
    exit /b 1
)

echo === Building piper_plus shared library (upstream C API, CPU only) ===
if not exist "%PIPER_DIR%\build" mkdir "%PIPER_DIR%\build"
cmake -S "%PIPER_DIR%" -B "%PIPER_DIR%\build" ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DPIPER_PLUS_BUILD_SHARED=ON ^
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON
if errorlevel 1 (
    echo ERROR: cmake configure failed
    exit /b 1
)
cmake --build "%PIPER_DIR%\build" --config Release --target piper_plus
if errorlevel 1 (
    echo ERROR: cmake build failed
    exit /b 1
)

echo === Copying DLLs to build output ===
set DLL_SRC=%PIPER_DIR%\build\Release\piper_plus.dll
if not exist "%DLL_SRC%" set DLL_SRC=%PIPER_DIR%\build\piper_plus.dll

set RUNNER_DIR=%PROJECT_ROOT%\build\windows\x64\runner\Release
if not exist "%RUNNER_DIR%" mkdir "%RUNNER_DIR%"
copy "%DLL_SRC%" "%RUNNER_DIR%\" /Y

REM One-shot migration: the fork-era DLL this script used to produce. Safe to
REM delete once no working tree predates piper-plus v2.
if exist "%RUNNER_DIR%\piper_tts_ffi.dll" del "%RUNNER_DIR%\piper_tts_ffi.dll"

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
