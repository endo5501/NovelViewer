## ADDED Requirements

### Requirement: Tabbed settings dialog
The settings dialog SHALL use a tabbed layout with `TabBar` and `TabBarView`. The tabs SHALL be: "一般" (General) containing all existing settings, and "読み上げ" (TTS) containing TTS-specific settings. All existing settings functionality SHALL be preserved in the "一般" tab.

#### Scenario: Display tabbed settings dialog
- **WHEN** the user opens the settings dialog
- **THEN** the dialog displays two tabs: "一般" and "読み上げ"

#### Scenario: General tab contains existing settings
- **WHEN** the user views the "一般" tab
- **THEN** all existing settings (display mode, theme, font size, font family, column spacing, LLM configuration) are displayed

#### Scenario: Switch between tabs
- **WHEN** the user clicks the "読み上げ" tab
- **THEN** the TTS settings are displayed, replacing the general settings content

### Requirement: TTS model size setting
The TTS settings tab SHALL include a model size selection control (SegmentedButton) with options "高速 (0.6B)" and "高精度 (1.7B)". The selected model size SHALL be persisted using SharedPreferences with key `tts_model_size`. The default SHALL be `small`.

#### Scenario: Display model size selector in TTS tab
- **WHEN** the user opens the TTS settings tab
- **THEN** a SegmentedButton with "高速 (0.6B)" and "高精度 (1.7B)" is displayed at the top of the tab

#### Scenario: Change model size selection
- **WHEN** the user taps a different model size segment
- **THEN** the selection is updated, persisted, and the download status reflects the newly selected model

### Requirement: Download status display per model size
The TTS settings tab SHALL display the download status for the currently selected model size. When the model is downloaded, it SHALL show "✅ 利用可能". When not downloaded, it SHALL show a download button. During download, it SHALL show a progress bar with file name and percentage.

#### Scenario: Downloaded model shows available status
- **WHEN** the selected model size has been downloaded
- **THEN** the UI displays a checkmark icon with "ダウンロード済み" text

#### Scenario: Undownloaded model shows download button
- **WHEN** the selected model size has not been downloaded
- **THEN** a "モデルデータダウンロード" button is displayed

#### Scenario: Download in progress shows progress bar
- **WHEN** a model download is in progress
- **THEN** a progress bar is displayed with the current file name and percentage

### Requirement: Voice cloning reference audio file setting
The TTS settings tab SHALL include a dropdown selector for choosing a voice cloning reference audio file from the `voices` directory. The dropdown SHALL list all supported audio files (`.wav`, `.mp3`) found in the `voices` directory. The selected file name SHALL be persisted using SharedPreferences. When no file is selected, TTS SHALL use default voice synthesis without cloning. The system SHALL provide a button to open the `voices` directory in the platform file manager, a refresh button to rescan the directory, and a rename button for the currently selected file. The voice reference selector area SHALL be wrapped in a drop zone that accepts audio files dragged from the platform's native file manager.

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

#### Scenario: Display rename button for selected file
- **WHEN** a voice reference file (not default) is selected in the dropdown
- **THEN** a rename button (edit icon) is displayed in the button row

#### Scenario: Hide rename button for default selection
- **WHEN** "なし（デフォルト音声）" is selected in the dropdown
- **THEN** the rename button is not displayed

#### Scenario: Drop zone wraps the voice reference selector
- **WHEN** the user views the TTS settings tab
- **THEN** the voice reference selector area is wrapped in a drop zone that accepts file drops from the native file manager

#### Scenario: TTS with voice cloning when file selected
- **WHEN** a valid voice reference file is selected and the user starts TTS playback
- **THEN** TTS uses the resolved full path of the selected file as the voice cloning reference

#### Scenario: Voice reference setting persists across app restarts
- **WHEN** the user selects a voice reference file and restarts the application
- **THEN** the previously selected file name is restored in the TTS settings

### Requirement: Updated TTS settings persistence
All TTS settings (model size, voice reference file name) SHALL be persisted using SharedPreferences and restored when the application starts. The model size SHALL be stored as the enum name (`"small"` or `"large"`). The voice reference SHALL be stored as a file name only. The model directory path SHALL NOT be persisted; it SHALL be derived at runtime.

#### Scenario: Persist model size and voice reference
- **WHEN** the user configures model size as "高精度 (1.7B)" and selects a voice reference file
- **THEN** `"large"` is saved under `tts_model_size` and the voice file name is saved under `tts_ref_wav_path`

#### Scenario: Restore TTS settings on startup
- **WHEN** the application starts with previously saved TTS settings
- **THEN** the model size and voice reference file name are restored

#### Scenario: Default state with no TTS configuration
- **WHEN** the application starts for the first time
- **THEN** model size defaults to `small` and voice reference is empty

### Requirement: TTS model download section in settings
The TTS settings tab SHALL include a model download section that displays different content based on the current download state for the selected model size.

#### Scenario: Display download button when models not downloaded
- **WHEN** the user opens the TTS settings tab and model files are not present for the selected model size
- **THEN** a "モデルデータダウンロード" button is displayed

#### Scenario: Display download progress during download
- **WHEN** a model download is in progress
- **THEN** a progress bar is displayed with the current file name and progress percentage

#### Scenario: Display completed status when models exist
- **WHEN** the user opens the TTS settings tab and model files already exist for the selected model size
- **THEN** a "モデルダウンロード済み" status message is displayed

#### Scenario: Display error with retry option
- **WHEN** a model download fails with an error
- **THEN** an error message is displayed along with a retry button to attempt the download again
