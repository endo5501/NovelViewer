## MODIFIED Requirements

### Requirement: Tabbed settings dialog
The settings dialog SHALL use a tabbed layout with `TabBar` and `TabBarView`. The tabs SHALL be: "一般" (General) containing all existing settings, and "読み上げ" (TTS) containing TTS-specific settings. All existing settings functionality SHALL be preserved in the "一般" tab. The TTS tab SHALL display an engine selector (`SegmentedButton<TtsEngineType>`) at the top, followed by engine-specific settings that change based on the selected engine.

#### Scenario: Display tabbed settings dialog
- **WHEN** the user opens the settings dialog
- **THEN** the dialog displays two tabs: "一般" and "読み上げ"

#### Scenario: General tab contains existing settings
- **WHEN** the user views the "一般" tab
- **THEN** all existing settings (display mode, theme, font size, font family, column spacing, LLM configuration) are displayed

#### Scenario: Switch between tabs
- **WHEN** the user clicks the "読み上げ" tab
- **THEN** the TTS settings are displayed with engine selector at the top

#### Scenario: TTS tab shows engine selector first
- **WHEN** the user opens the "読み上げ" tab
- **THEN** a SegmentedButton for engine selection (Qwen3-TTS / Piper) is displayed at the top, before all other TTS settings

#### Scenario: Engine-specific settings displayed for qwen3
- **WHEN** the "Qwen3-TTS" engine is selected
- **THEN** the TTS tab shows language selector, model size selector, model download section, and voice reference selector below the engine selector

#### Scenario: Engine-specific settings displayed for piper
- **WHEN** the "Piper" engine is selected
- **THEN** the TTS tab shows piper model selector, piper model download section, and synthesis parameter sliders (lengthScale, noiseScale, noiseW) below the engine selector
