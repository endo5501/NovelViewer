## MODIFIED Requirements

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

## ADDED Requirements

### Requirement: The engine in use is one the platform supports
Every consumer that acts on the selected engine — the settings tab, the TTS controls bar, the edit dialog, model readiness and the engine configuration — SHALL use the selected engine only when the platform supports it. When the persisted engine is unsupported on the running platform, the engine in use SHALL be the first supported engine in the order Piper, Qwen3-TTS, Irodori-TTS. The persisted value SHALL NOT be rewritten by this resolution, so a reader who shares preferences across platforms, or restores them from a desktop backup, keeps their desktop choice there.

Selecting an engine in the settings tab SHALL persist that engine as before.

#### Scenario: The default engine resolves to Piper on iOS
- **WHEN** the application runs on iOS with no `tts_engine_type` persisted, so the stored default is `qwen3`
- **THEN** the engine in use is `piper`

#### Scenario: An unsupported persisted engine resolves without being rewritten
- **WHEN** the application runs on iOS with `tts_engine_type` persisted as `"irodori"`
- **THEN** the engine in use is `piper`, and `tts_engine_type` still holds `"irodori"`

#### Scenario: A supported persisted engine is used as is
- **WHEN** the application runs on a desktop platform with `tts_engine_type` persisted as `"irodori"`
- **THEN** the engine in use is `irodori`
