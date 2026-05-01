## Purpose

User selection between TTS engines (Qwen3-TTS / Piper). Defines the `TtsEngineType` enum, persists the choice via SharedPreferences (default qwen3), exposes a Riverpod provider, swaps the engine-specific settings panel with a SegmentedButton, and provides a Piper model dropdown when Piper is active.

## Requirements

### Requirement: TTS engine type enum
The system SHALL define a `TtsEngineType` enum with two values: `qwen3` (label "Qwen3-TTS") and `piper` (label "Piper"). The default engine type SHALL be `qwen3`.

#### Scenario: Enum values
- **WHEN** accessing `TtsEngineType.qwen3`
- **THEN** label is "Qwen3-TTS"

#### Scenario: Enum default
- **WHEN** no engine type has been persisted
- **THEN** the default is `TtsEngineType.qwen3`

### Requirement: TTS engine type persistence
The system SHALL persist the selected TTS engine type using SharedPreferences with key `tts_engine_type`. The stored value SHALL be the enum name (`"qwen3"` or `"piper"`).

#### Scenario: Persist engine type selection
- **WHEN** the user selects "Piper"
- **THEN** the value `"piper"` is saved to SharedPreferences under key `tts_engine_type`

#### Scenario: Restore engine type on startup
- **WHEN** the application starts with `tts_engine_type` set to `"piper"`
- **THEN** the engine type provider returns `TtsEngineType.piper`

#### Scenario: Default engine type for new installation
- **WHEN** the application starts with no `tts_engine_type` in SharedPreferences
- **THEN** the engine type provider returns `TtsEngineType.qwen3`

### Requirement: TTS engine type provider
The system SHALL provide a `ttsEngineTypeProvider` (Riverpod NotifierProvider) that exposes the current engine type and a `setEngineType(TtsEngineType)` method for updating and persisting the selection.

#### Scenario: Read current engine type
- **WHEN** `ttsEngineTypeProvider` is watched
- **THEN** it returns the currently persisted `TtsEngineType`

#### Scenario: Update engine type
- **WHEN** `ttsEngineTypeProvider.notifier.setEngineType(TtsEngineType.piper)` is called
- **THEN** the state changes to `TtsEngineType.piper` and the value is persisted

### Requirement: Engine selection UI in TTS settings tab
The TTS settings tab SHALL display a `SegmentedButton<TtsEngineType>` at the top of the tab, before all other settings. The two segments SHALL be labeled "Qwen3-TTS" and "Piper". Selecting an engine SHALL show only the settings relevant to that engine.

#### Scenario: Display engine selector
- **WHEN** the user opens the TTS settings tab
- **THEN** a SegmentedButton with "Qwen3-TTS" and "Piper" is displayed at the top

#### Scenario: Select qwen3 engine shows qwen3 settings
- **WHEN** the user selects "Qwen3-TTS"
- **THEN** the tab displays language selector, model size selector, model download section, and voice reference selector

#### Scenario: Select piper engine shows piper settings
- **WHEN** the user selects "Piper"
- **THEN** the tab displays piper model selector, piper model download section, and synthesis parameter sliders (lengthScale, noiseScale, noiseW)

#### Scenario: Select piper engine hides qwen3 settings
- **WHEN** the user selects "Piper"
- **THEN** the qwen3-specific settings (language, model size, voice reference) are NOT displayed

#### Scenario: Select qwen3 engine hides piper settings
- **WHEN** the user selects "Qwen3-TTS"
- **THEN** the piper-specific settings (piper model, synthesis parameters) are NOT displayed

### Requirement: Piper model selection setting
The TTS settings tab SHALL include a dropdown selector for choosing a piper model when the piper engine is selected. The initial available model SHALL be `ja_JP-tsukuyomi-chan-medium`. The selected model name SHALL be persisted using SharedPreferences with key `piper_model_name`. The default SHALL be `ja_JP-tsukuyomi-chan-medium`.

#### Scenario: Display piper model selector
- **WHEN** the piper engine is selected in settings
- **THEN** a dropdown displays available piper models with `ja_JP-tsukuyomi-chan-medium` as the default selection

#### Scenario: Persist piper model selection
- **WHEN** the user selects a different piper model
- **THEN** the model name is persisted to SharedPreferences under key `piper_model_name`
