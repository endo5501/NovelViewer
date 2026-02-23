## ADDED Requirements

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
