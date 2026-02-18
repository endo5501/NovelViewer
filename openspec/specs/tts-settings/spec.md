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
