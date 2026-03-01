## ADDED Requirements

### Requirement: TTS instruct text setting
The TTS settings tab SHALL include a text input field for specifying instruct text that controls TTS speech style. The field SHALL be labeled "発話スタイル指示" with placeholder text showing an example (e.g., "例: 優しく穏やかに話してください"). The instruct text SHALL be persisted using SharedPreferences with the key `tts_instruct`. An empty value SHALL mean no instruct is applied.

#### Scenario: Display instruct text field in TTS settings
- **WHEN** the user opens the "読み上げ" (TTS) settings tab
- **THEN** a text input field labeled "発話スタイル指示" is displayed with a placeholder example

#### Scenario: Set instruct text
- **WHEN** the user enters "怒りの口調で" in the instruct text field
- **THEN** the value "怒りの口調で" is persisted in SharedPreferences

#### Scenario: Clear instruct text
- **WHEN** the user clears the instruct text field
- **THEN** the empty string is persisted and TTS synthesis uses no instruct

#### Scenario: Instruct text persists across app restarts
- **WHEN** the user sets instruct text to "優しく話して" and restarts the application
- **THEN** the TTS settings tab displays "優しく話して" in the instruct text field

#### Scenario: Default state with no instruct configured
- **WHEN** the application starts for the first time with no instruct setting saved
- **THEN** the instruct text field is empty and TTS synthesis uses no instruct

### Requirement: TTS instruct setting persistence
The `SettingsRepository` SHALL provide `getTtsInstruct()` and `setTtsInstruct(String)` methods. The setting SHALL be stored as a string in SharedPreferences under the key `tts_instruct`. The `getTtsInstruct()` method SHALL return an empty string when no value is stored.

#### Scenario: Get instruct when not set
- **WHEN** `getTtsInstruct()` is called with no stored value
- **THEN** an empty string is returned

#### Scenario: Set and get instruct
- **WHEN** `setTtsInstruct("怒りの口調で")` is called followed by `getTtsInstruct()`
- **THEN** "怒りの口調で" is returned

### Requirement: TTS instruct provider
A Riverpod provider `ttsInstructProvider` SHALL expose the current instruct text setting. The provider SHALL read from `SettingsRepository` and invalidate when the setting changes.

#### Scenario: Provider returns current instruct text
- **WHEN** `ttsInstructProvider` is read after setting instruct to "Happy tone"
- **THEN** the provider returns "Happy tone"

#### Scenario: Provider returns empty when not configured
- **WHEN** `ttsInstructProvider` is read with no instruct configured
- **THEN** the provider returns an empty string
