## ADDED Requirements

### Requirement: Windows audio platform initialization
The system SHALL initialize the `just_audio_media_kit` platform implementation on Windows to enable audio playback via the `just_audio` API. Initialization SHALL occur in `main()` after `WidgetsFlutterBinding.ensureInitialized()` and before any audio playback is attempted. The initialization SHALL only be performed on Windows (`Platform.isWindows`). macOS SHALL continue to use `just_audio`'s built-in platform support without `just_audio_media_kit`.

#### Scenario: Audio playback works on Windows
- **WHEN** TTS generates a WAV file and `JustAudioPlayer` calls `setFilePath()` and `play()` on Windows
- **THEN** the audio is played back through the speakers using the media_kit backend

#### Scenario: Initialization runs only on Windows
- **WHEN** the app starts on Windows
- **THEN** `JustAudioMediaKit.ensureInitialized()` is called with `windows: true`

#### Scenario: macOS playback is unaffected
- **WHEN** the app starts on macOS
- **THEN** `JustAudioMediaKit.ensureInitialized()` is NOT called, and audio playback uses `just_audio`'s built-in macOS support

### Requirement: Windows audio dependencies
The system SHALL include `just_audio_media_kit` and `media_kit_libs_windows_audio` as dependencies in `pubspec.yaml` to provide Windows-compatible audio decoding and playback for `just_audio`.

#### Scenario: Dependencies are declared in pubspec.yaml
- **WHEN** `pubspec.yaml` is inspected
- **THEN** `just_audio_media_kit` and `media_kit_libs_windows_audio` are listed as dependencies
