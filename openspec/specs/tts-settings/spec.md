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

### Requirement: Voice cloning WAV file setting
The TTS settings tab SHALL include a field for specifying a WAV file path to be used as the voice cloning reference. The field SHALL display the current path in a text field with a file picker button. The path SHALL be persisted using SharedPreferences. When no WAV file is configured, TTS SHALL use default voice synthesis without cloning.

#### Scenario: Set WAV file via file picker
- **WHEN** the user clicks the file picker button next to the WAV file field
- **THEN** a native file selection dialog opens (filtered to .wav files), and the selected path is displayed in the text field and persisted

#### Scenario: Display current WAV file path
- **WHEN** the user opens the TTS settings tab with a previously configured WAV path
- **THEN** the text field displays the persisted path

#### Scenario: TTS without voice cloning when no WAV configured
- **WHEN** no WAV file path is configured and the user starts TTS playback
- **THEN** TTS uses default voice synthesis (without voice cloning)

#### Scenario: TTS with voice cloning when WAV configured
- **WHEN** a valid WAV file path is configured and the user starts TTS playback
- **THEN** TTS uses the specified WAV file as the voice cloning reference

#### Scenario: WAV file path persists across app restarts
- **WHEN** the user sets a WAV file path and restarts the application
- **THEN** the previously configured path is restored in the TTS settings

### Requirement: TTS settings persistence
All TTS settings (model directory path, WAV file path) SHALL be persisted using SharedPreferences and restored when the application starts.

#### Scenario: Persist all TTS settings
- **WHEN** the user configures model directory and WAV file paths
- **THEN** both values are saved to SharedPreferences

#### Scenario: Restore TTS settings on startup
- **WHEN** the application starts with previously saved TTS settings
- **THEN** the TTS model directory and WAV file paths are available to the TTS engine

#### Scenario: Default state with no TTS configuration
- **WHEN** the application starts for the first time with no TTS settings saved
- **THEN** both model directory and WAV file paths are empty and TTS functionality is unavailable

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
