@echo off
rem Clean build artifacts and stray Flutter log files at the repo root.
setlocal

pushd "%~dp0\.."

del /q flutter_*.log 2>nul
fvm flutter clean

popd

endlocal
