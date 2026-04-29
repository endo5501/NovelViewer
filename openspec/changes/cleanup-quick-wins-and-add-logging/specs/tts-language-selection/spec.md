## MODIFIED Requirements

### Requirement: TTS engine language application
The TTS engine SHALL apply the selected language when initializing. The `TtsIsolate.loadModel` method SHALL accept a `languageId` parameter. The TTS playback controllers (`TtsStreamingController` and `TtsEditController`) SHALL read the current language from `ttsLanguageProvider` and pass it to the isolate when triggering model load.

#### Scenario: Language applied during model load
- **WHEN** the TTS engine loads a model with languageId 2050
- **THEN** the engine calls `setLanguage(2050)` on the native context

#### Scenario: Language change between generations
- **WHEN** the user changes the language setting and starts a new TTS generation
- **THEN** the new generation uses the updated language setting
