## ADDED Requirements

### Requirement: TTS language enum definition
The system SHALL define a `TtsLanguage` enum with the following values and their corresponding language IDs: `en` (2050), `ru` (2069), `zh` (2055), `ja` (2058), `ko` (2064), `de` (2053), `fr` (2061), `es` (2054), `it` (2070), `pt` (2071). Each enum value SHALL have a `languageId` (int) property and a `displayName` (String) property for UI display.

#### Scenario: Enum contains all supported languages
- **WHEN** the TtsLanguage enum is referenced
- **THEN** it contains exactly 10 values: en, ru, zh, ja, ko, de, fr, es, it, pt

#### Scenario: Each language has correct language ID
- **WHEN** `TtsLanguage.ja.languageId` is accessed
- **THEN** it returns 2058

#### Scenario: Each language has display name
- **WHEN** `TtsLanguage.ja.displayName` is accessed
- **THEN** it returns "日本語"

### Requirement: TTS language persistence
The selected TTS language SHALL be persisted using SharedPreferences with key `tts_language`. The value stored SHALL be the enum name (e.g., `"ja"`, `"en"`). The default SHALL be `ja` (Japanese).

#### Scenario: Persist selected language
- **WHEN** the user selects English as the TTS language
- **THEN** `"en"` is saved under the `tts_language` key in SharedPreferences

#### Scenario: Restore language on startup
- **WHEN** the application starts with a previously saved language setting of `"en"`
- **THEN** the TTS language is restored to English

#### Scenario: Default language when no setting exists
- **WHEN** the application starts for the first time
- **THEN** the TTS language defaults to Japanese (ja)

#### Scenario: Invalid stored value falls back to default
- **WHEN** the application starts with an invalid value stored in `tts_language`
- **THEN** the TTS language defaults to Japanese (ja)

### Requirement: TTS language provider
The system SHALL provide a `ttsLanguageProvider` (Riverpod NotifierProvider) that manages the current TTS language selection. The notifier SHALL read the initial value from SettingsRepository and provide a `setLanguage` method to update both the state and persisted value.

#### Scenario: Provider returns current language
- **WHEN** `ttsLanguageProvider` is watched
- **THEN** it returns the currently selected TtsLanguage

#### Scenario: Update language via provider
- **WHEN** `setLanguage(TtsLanguage.en)` is called on the notifier
- **THEN** the provider state updates to English and the value is persisted

### Requirement: TTS engine language application
The TTS engine SHALL apply the selected language when initializing. The `TtsIsolate.loadModel` method SHALL accept a `languageId` parameter. The `TtsGenerationController` SHALL read the current language from the provider and pass it to the isolate.

#### Scenario: Language applied during model load
- **WHEN** the TTS engine loads a model with languageId 2050
- **THEN** the engine calls `setLanguage(2050)` on the native context

#### Scenario: Language change between generations
- **WHEN** the user changes the language setting and starts a new TTS generation
- **THEN** the new generation uses the updated language setting

### Requirement: TTS language setting UI
The TTS settings tab SHALL include a language selection dropdown (DropdownButtonFormField) displaying all supported languages with their display names. The dropdown SHALL be positioned above the model size selector. The selected language SHALL update the `ttsLanguageProvider`.

#### Scenario: Display language dropdown in TTS tab
- **WHEN** the user opens the TTS settings tab
- **THEN** a dropdown labeled "読み上げ言語" is displayed with all 10 supported languages

#### Scenario: Default selection is Japanese
- **WHEN** the user opens the TTS settings tab for the first time
- **THEN** the dropdown shows "日本語" as the selected value

#### Scenario: Change language selection
- **WHEN** the user selects "English" from the language dropdown
- **THEN** the selection is updated and persisted immediately
