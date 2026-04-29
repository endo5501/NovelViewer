## MODIFIED Requirements

### Requirement: TtsEngine language configuration
The `TtsEngine` class SHALL provide a `setLanguage` method that accepts an integer language ID and calls the native `qwen3_tts_set_language` function. The `setLanguage` method SHALL only be callable when the model is loaded. Callers SHALL pass the language ID via the `TtsLanguage` enum (e.g., `TtsLanguage.ja.languageId`); a top-level `languageJapanese` constant on `TtsEngine` SHALL NOT exist.

#### Scenario: Set language on loaded engine
- **WHEN** `setLanguage` is called with `TtsLanguage.ja.languageId` on a loaded `TtsEngine`
- **THEN** the native `qwen3_tts_set_language` is called with the context and language ID `2058`

#### Scenario: Set language on unloaded engine throws
- **WHEN** `setLanguage` is called on a `TtsEngine` that has not loaded a model
- **THEN** a `TtsEngineException` is thrown with message 'Model not loaded'
