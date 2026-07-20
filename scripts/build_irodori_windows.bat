@echo off
setlocal enabledelayedexpansion

REM Build the audio.cpp Irodori-TTS FFI shared library (audiocpp_ffi.dll) with
REM the Vulkan backend and copy it, plus the model spec, next to the Flutter
REM runner executable. Mirrors build_tts_windows.bat.

set SCRIPT_DIR=%~dp0
set PROJECT_ROOT=%SCRIPT_DIR%..
set AUDIO_DIR=%PROJECT_ROOT%\third_party\audio.cpp
set BUILD_DIR=%AUDIO_DIR%\build\ffi-vulkan

echo === Setting up MSVC environment ===
set VCVARS=C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat
if not exist "%VCVARS%" set VCVARS=C:\Program Files\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat
if not exist "%VCVARS%" (
    echo Could not find vcvars64.bat. Install Visual Studio 2022 with the C++ workload.
    exit /b 1
)
call "%VCVARS%" >nul
if errorlevel 1 (
    echo Failed to initialize MSVC environment
    exit /b 1
)

echo === Configuring audio.cpp (Vulkan + shared FFI) ===
REM Japanese-locale MSVC requires /utf-8 and /openmp:experimental (verified).
cmake -S "%AUDIO_DIR%" -B "%BUILD_DIR%" -G Ninja ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DCMAKE_C_COMPILER=cl ^
    -DCMAKE_CXX_COMPILER=cl ^
    "-DCMAKE_C_FLAGS=/utf-8" ^
    "-DCMAKE_CXX_FLAGS=/utf-8 /EHsc" ^
    "-DOpenMP_C_FLAGS=/openmp:experimental" ^
    "-DOpenMP_CXX_FLAGS=/openmp:experimental" ^
    -DENGINE_ENABLE_VULKAN=ON ^
    -DENGINE_ENABLE_OPENMP=ON ^
    -DGGML_OPENMP=ON ^
    -DAUDIOCPP_BUILD_SHARED=ON ^
    -DENGINE_BUILD_TESTS=OFF
if errorlevel 1 exit /b 1

echo === Building audiocpp_ffi ===
cmake --build "%BUILD_DIR%" --target audiocpp_ffi
if errorlevel 1 exit /b 1

echo === Copying DLL and model spec to build output ===
set DLL_SRC=%BUILD_DIR%\bin\audiocpp_ffi.dll
if not exist "%DLL_SRC%" set DLL_SRC=%BUILD_DIR%\audiocpp_ffi.dll

set RUNNER_DIR=%PROJECT_ROOT%\build\windows\x64\runner\Release
if not exist "%RUNNER_DIR%" mkdir "%RUNNER_DIR%"
copy "%DLL_SRC%" "%RUNNER_DIR%\" /Y

REM The shim resolves model_specs\irodori_tts.json next to the DLL itself.
set SPEC_DIR=%RUNNER_DIR%\model_specs
if not exist "%SPEC_DIR%" mkdir "%SPEC_DIR%"
copy "%AUDIO_DIR%\model_specs\irodori_tts.json" "%SPEC_DIR%\" /Y

echo === Done ===
echo DLL copied to:  %RUNNER_DIR%\audiocpp_ffi.dll
echo Spec copied to: %SPEC_DIR%\irodori_tts.json
