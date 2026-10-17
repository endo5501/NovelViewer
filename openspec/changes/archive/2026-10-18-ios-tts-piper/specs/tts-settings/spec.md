## MODIFIED Requirements

### Requirement: Tabbed settings dialog
The settings dialog SHALL use a tabbed layout with `TabBar` and `TabBarView`. On a platform where text-to-speech is available, the TTS tabs SHALL be: "一般" (General) containing all existing settings, and "読み上げ" (TTS) containing TTS-specific settings. All existing settings functionality SHALL be preserved in the "一般" tab. The TTS tab SHALL display, at the top, the engine selector where the platform supports more than one engine (`tts-engine-selection`), followed by the settings of the engine in use.

On a platform where text-to-speech is unavailable, the "読み上げ" tab SHALL NOT be listed and its content SHALL NOT be built, so that no control capable of loading the TTS native library, requesting microphone access, or invoking a desktop-only drag-and-drop plugin is reachable. The "一般" tab SHALL retain all of its settings unchanged.

#### Scenario: Display tabbed settings dialog
- **WHEN** the user opens the settings dialog on a platform where TTS is available
- **THEN** the dialog displays the "一般" and "読み上げ" tabs

#### Scenario: TTS tab is absent where TTS is unavailable
- **WHEN** the user opens the settings dialog on a platform where TTS is unavailable
- **THEN** no "読み上げ" tab is listed and its content is not built

#### Scenario: General tab contains existing settings
- **WHEN** the user views the "一般" tab
- **THEN** all existing settings (display mode, theme, font size, font family, column spacing, LLM configuration) are displayed

#### Scenario: Switch between tabs
- **WHEN** the user clicks the "読み上げ" tab
- **THEN** the TTS settings are displayed

#### Scenario: TTS tab shows engine selector first
- **WHEN** the user opens the "読み上げ" tab on a platform that supports more than one engine
- **THEN** a SegmentedButton for engine selection is displayed at the top, before all other TTS settings

#### Scenario: TTS tab on a single-engine platform
- **WHEN** the user opens the "読み上げ" tab on iOS
- **THEN** no engine selector is displayed, and the Piper settings (model download and synthesis parameters) are shown

#### Scenario: Engine-specific settings displayed for qwen3
- **WHEN** the "Qwen3-TTS" engine is selected
- **THEN** the TTS tab shows language selector, model size selector, model download section, and voice reference selector below the engine selector

#### Scenario: Engine-specific settings displayed for piper
- **WHEN** the "Piper" engine is selected
- **THEN** the TTS tab shows piper model selector, piper model download section, and synthesis parameter sliders (lengthScale, noiseScale, noiseW) below the engine selector
