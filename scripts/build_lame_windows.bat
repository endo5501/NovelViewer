@echo off
setlocal enabledelayedexpansion

set SCRIPT_DIR=%~dp0
set PROJECT_ROOT=%SCRIPT_DIR%..
set LAME_FFI_DIR=%PROJECT_ROOT%\third_party\lame_enc_ffi

echo === Building lame_enc_ffi shared library ===
if not exist "%LAME_FFI_DIR%\build" mkdir "%LAME_FFI_DIR%\build"
cmake -S "%LAME_FFI_DIR%" -B "%LAME_FFI_DIR%\build" ^
    -DCMAKE_BUILD_TYPE=Release
cmake --build "%LAME_FFI_DIR%\build" --config Release

echo === Copying DLL to build output ===
set DLL_SRC=%LAME_FFI_DIR%\build\Release\lame_enc_ffi.dll
if not exist "%DLL_SRC%" set DLL_SRC=%LAME_FFI_DIR%\build\lame_enc_ffi.dll

set RUNNER_DIR=%PROJECT_ROOT%\build\windows\x64\runner\Release
if not exist "%RUNNER_DIR%" mkdir "%RUNNER_DIR%"
copy "%DLL_SRC%" "%RUNNER_DIR%\" /Y

echo === Done ===
echo DLL copied to: %RUNNER_DIR%\lame_enc_ffi.dll
