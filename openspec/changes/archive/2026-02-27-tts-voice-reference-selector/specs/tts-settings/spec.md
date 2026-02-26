## MODIFIED Requirements

### Requirement: Voice cloning WAV file setting
The TTS settings tab SHALL include a dropdown selector for choosing a voice cloning reference audio file from the `voices` directory. The dropdown SHALL list all supported audio files (`.wav`, `.mp3`) found in the `voices` directory. The selected file name SHALL be persisted using SharedPreferences. When no file is selected, TTS SHALL use default voice synthesis without cloning. The system SHALL provide a button to open the `voices` directory in the platform file manager, and a refresh button to rescan the directory.

#### Scenario: Display voice reference dropdown with available files
- **WHEN** the user opens the TTS settings tab and the `voices` directory contains audio files
- **THEN** a dropdown selector displays "なし（デフォルト音声）" as the first option followed by available audio file names sorted alphabetically

#### Scenario: Select a voice reference file from dropdown
- **WHEN** the user selects a file name from the voice reference dropdown
- **THEN** the file name is persisted and used as the voice cloning reference for TTS synthesis

#### Scenario: Select no voice reference (default voice)
- **WHEN** the user selects "なし（デフォルト音声）" from the dropdown
- **THEN** the setting is cleared and TTS uses default voice synthesis without cloning

#### Scenario: Display dropdown when voices directory is empty
- **WHEN** the user opens the TTS settings tab and the `voices` directory contains no supported audio files
- **THEN** the dropdown is disabled with hint text indicating that audio files should be placed in the `voices` folder

#### Scenario: Restore previously selected voice reference
- **WHEN** the user opens the TTS settings tab with a previously saved voice reference file name
- **AND** the file still exists in the `voices` directory
- **THEN** the dropdown shows the previously selected file as the current selection

#### Scenario: Previously selected file no longer exists
- **WHEN** the user opens the TTS settings tab with a previously saved voice reference file name
- **AND** the file no longer exists in the `voices` directory
- **THEN** the dropdown shows "なし（デフォルト音声）" as the current selection

#### Scenario: Open voices directory from settings
- **WHEN** the user clicks the folder open button next to the voice reference dropdown
- **THEN** the `voices` directory is opened in the platform's native file manager

#### Scenario: Refresh voice file list
- **WHEN** the user clicks the refresh button next to the voice reference dropdown
- **THEN** the `voices` directory is rescanned and the dropdown options are updated

#### Scenario: TTS with voice cloning when file selected
- **WHEN** a valid voice reference file is selected and the user starts TTS playback
- **THEN** TTS uses the resolved full path of the selected file as the voice cloning reference

#### Scenario: Voice reference setting persists across app restarts
- **WHEN** the user selects a voice reference file and restarts the application
- **THEN** the previously selected file name is restored in the TTS settings

## ADDED Requirements

### Requirement: TTS settings persistence for voice reference file name
The settings repository SHALL store voice reference as a file name only (e.g., `narrator.mp3`). The full path SHALL be resolved at runtime by joining the voices directory path with the stored file name.

#### Scenario: Save voice reference as file name
- **WHEN** the user selects `narrator.mp3` from the dropdown
- **THEN** the string `narrator.mp3` is persisted in SharedPreferences

#### Scenario: Load file name setting and resolve to full path
- **WHEN** the stored setting value is `narrator.mp3`
- **THEN** the system resolves it to `{LibraryParentDir}/voices/narrator.mp3` for synthesis
