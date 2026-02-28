## ADDED Requirements

### Requirement: Unicode file path support on Windows
The `load_wav_file`, `load_mp3_file`, and `save_audio_file` functions SHALL correctly handle file paths containing non-ASCII characters (e.g., Japanese, Chinese, Korean) on Windows. On Windows, UTF-8 encoded file paths SHALL be converted to UTF-16 (wchar_t) using `MultiByteToWideChar(CP_UTF8, ...)` before opening files. WAV file operations SHALL use `_wfopen()` instead of `fopen()`. MP3 file operations SHALL use `mp3dec_load_w()` instead of `mp3dec_load()`. On non-Windows platforms, the existing `fopen()` and `mp3dec_load()` SHALL continue to be used unchanged.

#### Scenario: Load WAV file with Japanese filename on Windows
- **WHEN** `load_audio_file` is called with a UTF-8 encoded path containing Japanese characters (e.g., `C:/voices/青年1.wav`) on Windows
- **THEN** the file is opened successfully using `_wfopen()` with the UTF-16 converted path, and audio samples are returned

#### Scenario: Load MP3 file with Japanese filename on Windows
- **WHEN** `load_audio_file` is called with a UTF-8 encoded path containing Japanese characters (e.g., `C:/voices/ナレーター.mp3`) on Windows
- **THEN** the file is opened successfully using `mp3dec_load_w()` with the UTF-16 converted path, and audio samples are returned

#### Scenario: Save WAV file with Japanese filename on Windows
- **WHEN** `save_audio_file` is called with a UTF-8 encoded path containing Japanese characters on Windows
- **THEN** the file is created successfully using `_wfopen()` with the UTF-16 converted path

#### Scenario: ASCII filenames continue to work on Windows
- **WHEN** `load_audio_file` is called with an ASCII-only path (e.g., `C:/voices/seinen1.wav`) on Windows
- **THEN** the file is opened successfully (no regression)

#### Scenario: Non-Windows platforms unaffected
- **WHEN** `load_audio_file` or `save_audio_file` is called on macOS or Linux
- **THEN** the existing `fopen()` and `mp3dec_load()` functions are used without any UTF-16 conversion
