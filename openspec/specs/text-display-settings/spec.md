## ADDED Requirements

### Requirement: Text display mode setting
The system SHALL provide a setting to switch between horizontal (yokogaki) and vertical (tategaki) text display modes. The default display mode SHALL be horizontal.

#### Scenario: Setting is available in settings dialog
- **WHEN** the user opens the settings dialog
- **THEN** a toggle or selector for text display mode (horizontal/vertical) is visible

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
The system SHALL persist the text display mode setting using shared_preferences so that it survives application restarts.

#### Scenario: Setting is preserved across restart
- **WHEN** the user sets vertical display mode and restarts the application
- **THEN** the application launches with vertical display mode

#### Scenario: Setting is loaded on startup
- **WHEN** the application launches with a previously saved display mode setting
- **THEN** the saved display mode is applied before the first text is rendered

### Requirement: Settings state management
The system SHALL manage the display mode setting via a Riverpod provider, allowing reactive updates across the application when the setting changes.

#### Scenario: Text viewer reacts to setting change
- **WHEN** the display mode setting is changed via the settings dialog
- **THEN** the text viewer widget rebuilds to reflect the new display mode without requiring navigation or page reload

#### Scenario: Setting is accessible from any widget
- **WHEN** any widget in the application reads the display mode provider
- **THEN** it receives the current display mode value
