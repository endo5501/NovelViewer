## Purpose

User-facing language selection (ja/en/zh) for the application UI. Persisted in SharedPreferences (default: ja), exposed via a Riverpod `Locale` provider that triggers a MaterialApp rebuild, and selected from a top-of-settings dropdown displaying each option in its own native name.

## Requirements

### Requirement: Language setting persistence
The system SHALL persist the user's language selection in SharedPreferences under a `locale` key. The stored value SHALL be the locale language code (`ja`, `en`, or `zh`). When no value is stored, the default locale SHALL be `ja` (Japanese).

#### Scenario: Default locale on first launch
- **WHEN** the application launches for the first time with no saved locale setting
- **THEN** the locale is `ja`

#### Scenario: Language selection is preserved across restart
- **WHEN** the user selects English and restarts the application
- **THEN** the application launches with English locale

#### Scenario: Language selection is preserved for Chinese
- **WHEN** the user selects Simplified Chinese and restarts the application
- **THEN** the application launches with Simplified Chinese locale

### Requirement: Language setting state management
The system SHALL manage the locale setting via a Riverpod provider that exposes the current `Locale` and provides a method to change it. Changing the locale SHALL immediately update the provider value, persist to SharedPreferences, and trigger MaterialApp to rebuild.

#### Scenario: Locale provider reflects current setting
- **WHEN** any widget reads the locale provider
- **THEN** it receives the current locale value

#### Scenario: Changing locale triggers immediate UI update
- **WHEN** the user changes the language setting
- **THEN** the locale provider updates and all localized text across the app changes immediately without navigation

### Requirement: Language selection UI
The settings dialog general tab SHALL display a language selector as the first item (above the vertical display toggle). The selector SHALL be a DropdownButton showing the available languages. Each language SHALL be displayed in its own language: "日本語", "English", "中文". The currently selected language SHALL be pre-selected.

#### Scenario: Language selector is visible in settings
- **WHEN** the user opens the settings dialog general tab
- **THEN** a language dropdown is visible as the first setting item

#### Scenario: Language options display in native names
- **WHEN** the language dropdown is expanded
- **THEN** three options are shown: "日本語", "English", "中文"

#### Scenario: Selecting a language updates the UI
- **WHEN** the user selects "English" from the language dropdown
- **THEN** the settings dialog and all visible UI text switch to English immediately
