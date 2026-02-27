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

### Requirement: TTS model directory path setting
The TTS settings tab SHALL include a field for specifying the directory path containing GGUF model files. The field SHALL display the current path in a text field with a folder picker button. The path SHALL be persisted using SharedPreferences.

#### Scenario: Set model directory via folder picker
- **WHEN** the user clicks the folder picker button next to the model directory field
- **THEN** a native folder selection dialog opens, and the selected path is displayed in the text field and persisted

#### Scenario: Display current model directory path
- **WHEN** the user opens the TTS settings tab with a previously configured model path
- **THEN** the text field displays the persisted path

#### Scenario: Clear model directory path
- **WHEN** the user clears the model directory text field
- **THEN** the empty path is persisted and TTS functionality is unavailable

#### Scenario: Model directory persists across app restarts
- **WHEN** the user sets a model directory path and restarts the application
- **THEN** the previously configured path is restored in the TTS settings

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

### Requirement: TTS settings persistence
All TTS settings (model directory path, voice reference file name) SHALL be persisted using SharedPreferences and restored when the application starts. The voice reference SHALL be stored as a file name only (e.g., `narrator.mp3`). The full path SHALL be resolved at runtime by joining the voices directory path with the stored file name.

#### Scenario: Persist all TTS settings
- **WHEN** the user configures model directory and voice reference file
- **THEN** both values are saved to SharedPreferences

#### Scenario: Restore TTS settings on startup
- **WHEN** the application starts with previously saved TTS settings
- **THEN** the TTS model directory and voice reference file name are available to the TTS engine

#### Scenario: Default state with no TTS configuration
- **WHEN** the application starts for the first time with no TTS settings saved
- **THEN** both model directory and voice reference file name are empty and TTS functionality is unavailable

#### Scenario: Save voice reference as file name
- **WHEN** the user selects `narrator.mp3` from the dropdown
- **THEN** the string `narrator.mp3` is persisted in SharedPreferences

#### Scenario: Load file name setting and resolve to full path
- **WHEN** the stored setting value is `narrator.mp3`
- **THEN** the system resolves it to `{LibraryParentDir}/voices/narrator.mp3` for synthesis

### Requirement: TTS model download section in settings
The TTS settings tab SHALL include a model download section positioned above the existing model directory and WAV file path fields. The section SHALL display different content based on the current download state.

#### Scenario: Display download button when models not downloaded
- **WHEN** the user opens the TTS settings tab and model files are not present in the models directory
- **THEN** a "モデルデータダウンロード" button is displayed

#### Scenario: Display download progress during download
- **WHEN** a model download is in progress
- **THEN** a progress bar is displayed with the current file name and progress percentage

#### Scenario: Display completed status when models exist
- **WHEN** the user opens the TTS settings tab and both model files already exist in the models directory
- **THEN** a "モデルダウンロード済み" status message is displayed with the models directory path

#### Scenario: Display error with retry option
- **WHEN** a model download fails with an error
- **THEN** an error message is displayed along with a retry button to attempt the download again

### Requirement: Model directory auto-fill after download
The TTS settings tab SHALL automatically update the model directory text field when a download completes successfully. The text field SHALL reflect the models directory path without requiring manual input from the user.

#### Scenario: Auto-fill model directory field on download completion
- **WHEN** both model files have been downloaded successfully
- **THEN** the model directory text field is updated to show the models directory path and the setting is persisted

#### Scenario: Model directory field remains editable after auto-fill
- **WHEN** the model directory has been auto-filled after download
- **THEN** the user can still manually edit the model directory text field or use the folder picker to choose a different directory
