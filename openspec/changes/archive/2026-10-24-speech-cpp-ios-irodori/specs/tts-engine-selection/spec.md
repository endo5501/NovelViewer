## MODIFIED Requirements

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
