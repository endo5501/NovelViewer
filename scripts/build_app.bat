@echo off
rem Builds the app with the commit it was made from, so a failure report from
rem the build can name the code that produced it (mirror of build_app.sh).
rem
rem The declared version holds still between releases, so without this every
rem build since the last release reports the same string. A plain
rem `fvm flutter build windows` still works; its reports say "commit unknown".
rem
rem It also hands the build the Google OAuth client values that progress sync
rem needs, from config\google_oauth.json when that file exists (see
rem docs/progress-sync.md). Without it the build has no sync, and nothing else
rem changes. NOVEL_VIEWER_OAUTH_CONFIG names a different file.
rem
rem Usage: scripts\build_app.bat windows [flutter build arguments...]
setlocal

if "%~1"=="" (
    echo usage: %~nx0 ^<windows^> [flutter build arguments...] 1>&2
    exit /b 64
)

cd /d "%~dp0.."

set "OAUTH_CONFIG=%NOVEL_VIEWER_OAUTH_CONFIG%"
if not defined OAUTH_CONFIG set "OAUTH_CONFIG=config\google_oauth.json"
set "OAUTH_DEFINE="
if exist "%OAUTH_CONFIG%" set OAUTH_DEFINE="--dart-define-from-file=%OAUTH_CONFIG%"

set "COMMIT="
for /f "delims=" %%h in ('git rev-parse --short HEAD 2^>nul') do set "COMMIT=%%h"

if defined COMMIT (
    call fvm flutter build %* %OAUTH_DEFINE% --dart-define=BUILD_COMMIT=%COMMIT%
) else (
    echo warning: git could not name the commit; this build will report "commit unknown" 1>&2
    call fvm flutter build %* %OAUTH_DEFINE%
)
exit /b %ERRORLEVEL%
