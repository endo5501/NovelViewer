## ADDED Requirements

### Requirement: TTS model size enum
The system SHALL define a `TtsModelSize` enum with two values: `small` (0.6B, label "高速") and `large` (1.7B, label "高精度"). Each enum value SHALL have a `dirName` property (`"0.6b"` or `"1.7b"`) and a `modelFileName` property (`"qwen3-tts-0.6b-f16.gguf"` or `"qwen3-tts-1.7b-f16.gguf"`).

#### Scenario: Enum values and properties
- **WHEN** accessing `TtsModelSize.small`
- **THEN** `dirName` is `"0.6b"`, `modelFileName` is `"qwen3-tts-0.6b-f16.gguf"`, and label is `"高速"`

#### Scenario: Large model properties
- **WHEN** accessing `TtsModelSize.large`
- **THEN** `dirName` is `"1.7b"`, `modelFileName` is `"qwen3-tts-1.7b-f16.gguf"`, and label is `"高精度"`

### Requirement: TTS model size persistence
The system SHALL persist the selected TTS model size using SharedPreferences with key `tts_model_size`. The stored value SHALL be the enum name (`"small"` or `"large"`). The default value SHALL be `small` (0.6B).

#### Scenario: Persist model size selection
- **WHEN** the user selects "高精度 (1.7B)"
- **THEN** the value `"large"` is saved to SharedPreferences under key `tts_model_size`

#### Scenario: Restore model size on startup
- **WHEN** the application starts with `tts_model_size` set to `"large"`
- **THEN** the model size provider returns `TtsModelSize.large`

#### Scenario: Default model size for new installation
- **WHEN** the application starts with no `tts_model_size` in SharedPreferences
- **THEN** the model size provider returns `TtsModelSize.small`

### Requirement: Automatic model directory resolution
The system SHALL automatically resolve the TTS model directory path from the selected model size. The path SHALL be `{modelsBaseDir}/{modelSize.dirName}/` where `modelsBaseDir` is resolved from the library path. The `ttsModelDirProvider` SHALL be a read-only Provider (not a writable Notifier) that derives its value from `ttsModelSizeProvider` and `modelsDirectoryPathProvider`.

#### Scenario: Resolve directory for 0.6B model
- **WHEN** the library path is `~/Documents/NovelViewer` and model size is `small`
- **THEN** the model directory resolves to `~/Documents/models/0.6b`

#### Scenario: Resolve directory for 1.7B model
- **WHEN** the library path is `~/Documents/NovelViewer` and model size is `large`
- **THEN** the model directory resolves to `~/Documents/models/1.7b`

### Requirement: Legacy directory migration
The system SHALL automatically migrate model files from the legacy directory structure (`models/` root) to the new structure (`models/0.6b/`) on startup. Migration SHALL move `qwen3-tts-0.6b-f16.gguf`, `qwen3-tts-tokenizer-f16.gguf`, and `.tts_models_complete` from `models/` to `models/0.6b/`. Migration SHALL only occur when legacy files exist and `models/0.6b/` does not already contain a complete set.

#### Scenario: Migrate legacy 0.6B model files
- **WHEN** the application starts and `models/qwen3-tts-0.6b-f16.gguf` exists
- **AND** `models/0.6b/` does not contain a complete model set
- **THEN** the system creates `models/0.6b/` and moves the model files, tokenizer, and completion marker into it

#### Scenario: Skip migration when no legacy files exist
- **WHEN** the application starts and `models/qwen3-tts-0.6b-f16.gguf` does not exist
- **THEN** no migration is performed

#### Scenario: Skip migration when new structure already exists
- **WHEN** the application starts and `models/0.6b/` already contains a complete model set
- **THEN** no migration is performed even if legacy files also exist

### Requirement: Model size selection UI
The TTS settings tab SHALL display a SegmentedButton for model size selection with two segments: "高速 (0.6B)" and "高精度 (1.7B)". Selecting a segment SHALL update the persisted model size and trigger re-evaluation of the download state for the selected model.

#### Scenario: Display model size selector
- **WHEN** the user opens the TTS settings tab
- **THEN** a SegmentedButton is displayed with "高速 (0.6B)" and "高精度 (1.7B)" segments

#### Scenario: Switch model size
- **WHEN** the user selects "高精度 (1.7B)" and the current selection is "高速 (0.6B)"
- **THEN** the model size setting is updated to `large` and the download state reflects whether the 1.7B model is already downloaded

#### Scenario: Show download status for selected model
- **WHEN** the user selects a model size that has already been downloaded
- **THEN** the UI displays "✅ 利用可能" status

#### Scenario: Show download button for undownloaded model
- **WHEN** the user selects a model size that has not been downloaded
- **THEN** a "モデルデータダウンロード" button is displayed
