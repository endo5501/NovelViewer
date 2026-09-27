@echo off
rem Builds the app with the commit it was made from, so a failure report from
rem the build can name the code that produced it (mirror of build_app.sh).
rem
rem The declared version holds still between releases, so without this every
rem build since the last release reports the same string. A plain
rem `fvm flutter build windows` still works; its reports say "commit unknown".
rem
rem Usage: scripts\build_app.bat windows [flutter build arguments...]
setlocal

if "%~1"=="" (
    echo usage: %~nx0 ^<windows^> [flutter build arguments...] 1>&2
    exit /b 64
)

cd /d "%~dp0.."

set "COMMIT="
for /f "delims=" %%h in ('git rev-parse --short HEAD 2^>nul') do set "COMMIT=%%h"

if defined COMMIT (
    call fvm flutter build %* --dart-define=BUILD_COMMIT=%COMMIT%
) else (
    echo warning: git could not name the commit; this build will report "commit unknown" 1>&2
    call fvm flutter build %*
)
exit /b %ERRORLEVEL%
