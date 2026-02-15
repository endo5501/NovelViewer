## ADDED Requirements

### Requirement: Text display mode setting
The system SHALL provide a setting to switch between horizontal (yokogaki) and vertical (tategaki) text display modes. The default display mode SHALL be horizontal. The settings dialog SHALL also include font size, font family, and column spacing controls below the display mode toggle.

#### Scenario: Setting is available in settings dialog
- **WHEN** the user opens the settings dialog
- **THEN** a toggle or selector for text display mode (horizontal/vertical) is visible
- **AND** a font size slider is visible below the display mode toggle
- **AND** a font family dropdown is visible below the font size slider
- **AND** a column spacing slider is visible below the font family dropdown

#### Scenario: Default display mode is horizontal
- **WHEN** the application launches for the first time with no saved settings
- **THEN** the text display mode is horizontal

#### Scenario: Switching to vertical mode
- **WHEN** the user selects vertical display mode in the settings dialog
- **THEN** the text viewer immediately switches to vertical text rendering

#### Scenario: Switching back to horizontal mode
- **WHEN** the user selects horizontal display mode in the settings dialog
- **THEN** the text viewer immediately switches to horizontal text rendering

### Requirement: Settings persistence
The system SHALL persist the text display mode setting and column spacing setting using shared_preferences so that they survive application restarts.

#### Scenario: Display mode setting is preserved across restart
- **WHEN** the user sets vertical display mode and restarts the application
- **THEN** the application launches with vertical display mode

#### Scenario: Column spacing setting is preserved across restart
- **WHEN** the user changes the column spacing and restarts the application
- **THEN** the application launches with the previously saved column spacing value

#### Scenario: Settings are loaded on startup
- **WHEN** the application launches with previously saved settings
- **THEN** the saved display mode and column spacing are applied before the first text is rendered

### Requirement: Settings state management
The system SHALL manage the display mode setting and column spacing setting via Riverpod providers, allowing reactive updates across the application when the settings change.

#### Scenario: Text viewer reacts to display mode change
- **WHEN** the display mode setting is changed via the settings dialog
- **THEN** the text viewer widget rebuilds to reflect the new display mode without requiring navigation or page reload

#### Scenario: Text viewer reacts to column spacing change
- **WHEN** the column spacing setting is changed via the settings dialog
- **THEN** the vertical text viewer widget rebuilds with the new column spacing without requiring navigation or page reload

#### Scenario: Setting is accessible from any widget
- **WHEN** any widget in the application reads the display mode or column spacing provider
- **THEN** it receives the current value

### Requirement: Column spacing setting
The system SHALL provide a column spacing setting that controls the gap between columns in vertical text mode. The setting value SHALL represent the Wrap widget's `runSpacing` parameter. The default value SHALL be `8.0`. The minimum value SHALL be `0.0` and the maximum value SHALL be `24.0`. The slider SHALL use `1.0` step increments (24 divisions). The column spacing provider SHALL follow the same preview-then-persist pattern as the font size provider: `previewColumnSpacing()` for real-time updates during slider drag, and `persistColumnSpacing()` for saving when the drag ends.

#### Scenario: Default column spacing
- **WHEN** the application launches for the first time with no saved column spacing setting
- **THEN** the column spacing value is `8.0`

#### Scenario: Adjusting column spacing via slider
- **WHEN** the user drags the column spacing slider
- **THEN** the vertical text viewer updates in real-time to reflect the new column spacing

#### Scenario: Column spacing is persisted on slider release
- **WHEN** the user releases the column spacing slider
- **THEN** the column spacing value is saved to SharedPreferences

#### Scenario: Column spacing below minimum is clamped
- **WHEN** the column spacing value is set below `0.0`
- **THEN** the value is clamped to `0.0`

#### Scenario: Column spacing above maximum is clamped
- **WHEN** the column spacing value is set above `24.0`
- **THEN** the value is clamped to `24.0`
