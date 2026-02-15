## ADDED Requirements

### Requirement: Platform-specific font availability
The system SHALL define platform availability for each font family. Hiragino Mincho ProN and Hiragino Kaku Gothic ProN SHALL be marked as macOS-only. System default, YuMincho, and YuGothic SHALL be marked as available on both macOS and Windows. The font family selection UI SHALL only display fonts that are available on the current platform.

#### Scenario: Windows shows only compatible fonts
- **WHEN** the settings dialog is opened on Windows
- **THEN** the font family dropdown SHALL display only: システムデフォルト, 游明朝, 游ゴシック

#### Scenario: macOS shows all fonts
- **WHEN** the settings dialog is opened on macOS
- **THEN** the font family dropdown SHALL display all font families: システムデフォルト, ヒラギノ明朝, ヒラギノ角ゴ, 游明朝, 游ゴシック

### Requirement: Windows system default font fallback
The system SHALL fall back to Yu Mincho (`'YuMincho'`) when the system default font is selected on Windows. This ensures that vertical text punctuation characters (U+FE11, U+FE12) are rendered with correct positioning (upper-right of the character cell) rather than centered.

#### Scenario: System default on Windows uses Yu Mincho
- **WHEN** the font family is set to system default and the application is running on Windows
- **THEN** the effective font family name used for text rendering SHALL be `'YuMincho'`

#### Scenario: System default on macOS remains unchanged
- **WHEN** the font family is set to system default and the application is running on macOS
- **THEN** the effective font family name SHALL remain `null` (Flutter platform default)

#### Scenario: Explicit font selection is not affected by fallback
- **WHEN** a specific font family (not system default) is selected on any platform
- **THEN** the effective font family name SHALL be the selected font's fontFamilyName without modification

## MODIFIED Requirements

### Requirement: Font family setting
The system SHALL provide a font family setting that allows users to select from a predefined list of font families. The default font family SHALL be the system default.

The available font families SHALL be:
- System default (Yu Mincho on Windows, Flutter default on macOS)
- Hiragino Mincho ProN (ヒラギノ明朝) — macOS only
- Hiragino Kaku Gothic ProN (ヒラギノ角ゴ) — macOS only
- YuMincho (游明朝)
- YuGothic (游ゴシック)

#### Scenario: Default font family on first launch
- **WHEN** the application launches for the first time with no saved font family setting
- **THEN** the font family is the system default

#### Scenario: User selects a font family
- **WHEN** the user selects a font family from the dropdown in the settings dialog
- **THEN** the text viewer immediately re-renders text using the selected font family
