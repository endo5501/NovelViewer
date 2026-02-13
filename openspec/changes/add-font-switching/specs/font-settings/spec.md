## ADDED Requirements

### Requirement: Font size setting
The system SHALL provide a font size setting that allows users to adjust the text size in the viewer area. The font size SHALL be a numeric value in the range of 10.0 to 32.0 pixels, with a default value of 14.0.

#### Scenario: Default font size on first launch
- **WHEN** the application launches for the first time with no saved font size setting
- **THEN** the font size is 14.0

#### Scenario: User changes font size via slider
- **WHEN** the user adjusts the font size slider in the settings dialog
- **THEN** the text viewer immediately re-renders text at the new font size

#### Scenario: Font size is clamped to valid range
- **WHEN** a font size value outside the range 10.0–32.0 is encountered
- **THEN** the system SHALL clamp the value to the nearest boundary (10.0 or 32.0)

### Requirement: Font family setting
The system SHALL provide a font family setting that allows users to select from a predefined list of font families. The default font family SHALL be the system default.

The available font families SHALL be:
- System default (Flutter default font)
- Hiragino Mincho ProN (ヒラギノ明朝)
- Hiragino Kaku Gothic ProN (ヒラギノ角ゴ)
- YuMincho (游明朝)
- YuGothic (游ゴシック)

#### Scenario: Default font family on first launch
- **WHEN** the application launches for the first time with no saved font family setting
- **THEN** the font family is the system default

#### Scenario: User selects a font family
- **WHEN** the user selects a font family from the dropdown in the settings dialog
- **THEN** the text viewer immediately re-renders text using the selected font family

### Requirement: Font settings persistence
The system SHALL persist font size and font family settings using SharedPreferences so that they survive application restarts. The font size SHALL be stored as a double value with key `font_size`. The font family SHALL be stored as a string (enum name) with key `font_family`.

#### Scenario: Font size is preserved across restart
- **WHEN** the user sets font size to 20.0 and restarts the application
- **THEN** the application launches with font size 20.0

#### Scenario: Font family is preserved across restart
- **WHEN** the user selects Hiragino Mincho ProN and restarts the application
- **THEN** the application launches with Hiragino Mincho ProN as the font family

#### Scenario: Corrupted font family value falls back to default
- **WHEN** the stored font family value does not match any known enum value
- **THEN** the system SHALL use the system default font family

### Requirement: Font settings state management
The system SHALL manage font size and font family settings via separate Riverpod NotifierProviders (`fontSizeProvider` and `fontFamilyProvider`), allowing reactive updates across the application when settings change.

#### Scenario: Text viewer reacts to font size change
- **WHEN** the font size setting is changed via the settings dialog
- **THEN** the text viewer widget rebuilds to reflect the new font size without requiring navigation or page reload

#### Scenario: Text viewer reacts to font family change
- **WHEN** the font family setting is changed via the settings dialog
- **THEN** the text viewer widget rebuilds to reflect the new font family without requiring navigation or page reload

#### Scenario: Vertical text pagination recalculates on font size change
- **WHEN** the font size setting is changed while viewing text in vertical mode
- **THEN** the vertical text viewer recalculates page layout and re-paginates content with the new font size

### Requirement: Font settings apply to both display modes
The system SHALL apply font size and font family settings to both horizontal and vertical text display modes. Ruby (furigana) text size SHALL scale proportionally with the base font size, maintaining the existing 0.5x ratio.

#### Scenario: Font size applies to horizontal mode
- **WHEN** the user sets font size to 20.0 and views text in horizontal mode
- **THEN** the horizontal text is rendered at 20.0px font size

#### Scenario: Font size applies to vertical mode
- **WHEN** the user sets font size to 20.0 and views text in vertical mode
- **THEN** the vertical text is rendered at 20.0px font size

#### Scenario: Ruby text scales with base font size
- **WHEN** the user sets font size to 20.0
- **THEN** ruby (furigana) text is rendered at 10.0px (0.5x base size)

#### Scenario: Font family applies to both modes
- **WHEN** the user selects Hiragino Mincho ProN
- **THEN** both horizontal and vertical text are rendered using Hiragino Mincho ProN
