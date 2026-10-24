## Purpose

User selection between TTS engines (Qwen3-TTS / Piper / Irodori-TTS). Defines the `TtsEngineType` enum, persists the choice via SharedPreferences (default qwen3), exposes a Riverpod provider, offers only the engines the platform runs (Piper alone on iOS, with no selector) and resolves an unsupported stored choice to a supported engine without rewriting it, swaps the engine-specific settings panel with a SegmentedButton, and provides a Piper model dropdown when Piper is active.

## Requirements

### Requirement: TTS engine type enum
The system SHALL define a `TtsEngineType` enum with three values: `qwen3` (label "Qwen3-TTS"), `piper` (label "Piper"), and `irodori` (label "Irodori-TTS"). The default engine type SHALL be `qwen3`.

#### Scenario: Enum values
- **WHEN** accessing `TtsEngineType.qwen3`
- **THEN** label is "Qwen3-TTS"

#### Scenario: Irodori enum value
- **WHEN** accessing `TtsEngineType.irodori`
- **THEN** label is "Irodori-TTS"

#### Scenario: Enum default
- **WHEN** no engine type has been persisted
- **THEN** the default is `TtsEngineType.qwen3`

### Requirement: TTS engine type persistence
The system SHALL persist the selected TTS engine type using SharedPreferences with key `tts_engine_type`. The stored value SHALL be the enum name (`"qwen3"`, `"piper"`, or `"irodori"`).

#### Scenario: Persist engine type selection
- **WHEN** the user selects "Piper"
- **THEN** the value `"piper"` is saved to SharedPreferences under key `tts_engine_type`

#### Scenario: Persist irodori selection
- **WHEN** the user selects "Irodori-TTS"
- **THEN** the value `"irodori"` is saved to SharedPreferences under key `tts_engine_type`

#### Scenario: Restore engine type on startup
- **WHEN** the application starts with `tts_engine_type` set to `"irodori"`
- **THEN** the engine type provider returns `TtsEngineType.irodori`

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
The TTS settings tab SHALL display a `SegmentedButton<TtsEngineType>` at the top of the tab, before all other settings, listing only the engines the platform supports, in the order Qwen3-TTS, Piper, Irodori-TTS. Selecting an engine SHALL show only the settings relevant to that engine. Where the platform supports a single engine, the selector SHALL NOT be displayed, since it would offer no choice, and that engine's settings SHALL be shown directly.

#### Scenario: Display engine selector
- **WHEN** the user opens the TTS settings tab on a platform that supports all three engines
- **THEN** a SegmentedButton with "Qwen3-TTS", "Piper", and "Irodori-TTS" is displayed at the top

#### Scenario: Only supported engines are offered
- **WHEN** the TTS settings tab is opened on a platform that supports some engines but not others
- **THEN** the selector lists only the supported engines

#### Scenario: No selector where one engine is supported
- **WHEN** the TTS settings tab is opened on iOS, where only Piper is supported
- **THEN** no engine selector is displayed, and the Piper settings are shown at the top of the tab

#### Scenario: Select qwen3 engine shows qwen3 settings
- **WHEN** the user selects "Qwen3-TTS"
- **THEN** the tab displays language selector, model size selector, model download section, and voice reference selector

#### Scenario: Select piper engine shows piper settings
- **WHEN** the user selects "Piper"
- **THEN** the tab displays piper model selector, piper model download section, and synthesis parameter sliders (lengthScale, noiseScale, noiseW)

#### Scenario: Select irodori engine shows irodori settings
- **WHEN** the user selects "Irodori-TTS"
- **THEN** the tab displays the Irodori model download section, voice reference selector, and Irodori synthesis parameters (speaker_guidance_scale, caption_guidance_scale, num_inference_steps)

#### Scenario: Select piper engine hides qwen3 settings
- **WHEN** the user selects "Piper"
- **THEN** the qwen3-specific settings (language, model size, voice reference) are NOT displayed

#### Scenario: Select qwen3 engine hides piper settings
- **WHEN** the user selects "Qwen3-TTS"
- **THEN** the piper-specific settings (piper model, synthesis parameters) are NOT displayed

#### Scenario: Select irodori engine hides other engines' settings
- **WHEN** the user selects "Irodori-TTS"
- **THEN** the qwen3-specific settings (language, model size) and piper-specific settings (piper model, piper parameters) are NOT displayed

### Requirement: Piper model selection setting
The TTS settings tab SHALL include a dropdown selector for choosing a piper model when the piper engine is selected. The initial available model SHALL be `ja_JP-tsukuyomi-chan-medium`. The selected model name SHALL be persisted using SharedPreferences with key `piper_model_name`. The default SHALL be `ja_JP-tsukuyomi-chan-medium`.

#### Scenario: Display piper model selector
- **WHEN** the piper engine is selected in settings
- **THEN** a dropdown displays available piper models with `ja_JP-tsukuyomi-chan-medium` as the default selection

#### Scenario: Persist piper model selection
- **WHEN** the user selects a different piper model
- **THEN** the model name is persisted to SharedPreferences under key `piper_model_name`

### Requirement: The engine in use is one the platform supports
Every consumer that acts on the selected engine — the settings tab, the TTS controls bar, the edit dialog, model readiness and the engine configuration — SHALL use the selected engine only when the platform supports it. When the persisted engine is unsupported on the running platform, the engine in use SHALL be the first supported engine in the order Piper, Qwen3-TTS, Irodori-TTS. The persisted value SHALL NOT be rewritten by this resolution, so a reader who shares preferences across platforms, or restores them from a desktop backup, keeps their desktop choice there.

Selecting an engine in the settings tab SHALL persist that engine as before.

#### Scenario: The default engine resolves to Piper on iOS
- **WHEN** the application runs on iOS with no `tts_engine_type` persisted, so the stored default is `qwen3`
- **THEN** the engine in use is `piper`

#### Scenario: An unsupported persisted engine resolves without being rewritten
- **WHEN** the application runs on iOS with `tts_engine_type` persisted as `"qwen3"`
- **THEN** the engine in use is `piper`, and `tts_engine_type` still holds `"qwen3"`

#### Scenario: Irodori-TTS persisted on iOS is used as is
- **WHEN** the application runs on iOS with `tts_engine_type` persisted as `"irodori"`
- **THEN** the engine in use is `irodori`

#### Scenario: A supported persisted engine is used as is
- **WHEN** the application runs on a desktop platform with `tts_engine_type` persisted as `"irodori"`
- **THEN** the engine in use is `irodori`
