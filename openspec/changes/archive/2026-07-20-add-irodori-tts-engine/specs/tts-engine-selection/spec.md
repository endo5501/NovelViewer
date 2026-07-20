# tts-engine-selection (delta)

## MODIFIED Requirements

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

### Requirement: Engine selection UI in TTS settings tab
The TTS settings tab SHALL display a `SegmentedButton<TtsEngineType>` at the top of the tab, before all other settings. The three segments SHALL be labeled "Qwen3-TTS", "Piper", and "Irodori-TTS". Selecting an engine SHALL show only the settings relevant to that engine.

#### Scenario: Display engine selector
- **WHEN** the user opens the TTS settings tab
- **THEN** a SegmentedButton with "Qwen3-TTS", "Piper", and "Irodori-TTS" is displayed at the top

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
