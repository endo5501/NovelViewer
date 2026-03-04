## ADDED Requirements

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

## REMOVED Requirements

### Requirement: TTS model directory path setting
**Reason**: Replaced by automatic model directory resolution based on selected model size. The model directory is now derived from `models/{size}/` without manual configuration.
**Migration**: The `tts_model_dir` SharedPreferences key is no longer read. The model directory is automatically resolved from the selected `tts_model_size`.

### Requirement: Model directory auto-fill after download
**Reason**: No longer needed since model directory is automatically derived from model size selection, not stored as a separate setting.
**Migration**: Download completion no longer sets `ttsModelDirProvider`. The directory is always computed from `ttsModelSizeProvider`.

### Requirement: TTS settings persistence
**Reason**: Being replaced with updated persistence requirements that use `tts_model_size` instead of `tts_model_dir`.
**Migration**: `tts_model_dir` key is replaced by `tts_model_size` key. Voice reference persistence (`tts_ref_wav_path`) remains unchanged.

## ADDED Requirements

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
