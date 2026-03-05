## MODIFIED Requirements

### Requirement: Text display mode setting
The system SHALL provide a setting to switch between horizontal (yokogaki) and vertical (tategaki) text display modes. The default display mode SHALL be horizontal. The settings dialog general tab SHALL display a language selector as the first item, followed by the display mode toggle, font size, font family, and column spacing controls.

#### Scenario: Setting is available in settings dialog
- **WHEN** the user opens the settings dialog
- **THEN** a language selector is visible as the first item in the general tab
- **AND** a toggle or selector for text display mode (horizontal/vertical) is visible below the language selector
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
