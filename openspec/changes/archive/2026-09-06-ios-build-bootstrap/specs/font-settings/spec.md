## MODIFIED Requirements

### Requirement: Platform-specific font availability
The system SHALL define platform availability for each font family. Hiragino Mincho ProN and Hiragino Kaku Gothic ProN ship with every Apple platform and SHALL be marked as Apple-only — available on macOS and iOS, withheld elsewhere. System default, YuMincho, and YuGothic SHALL be marked as available on all platforms. The font family selection UI SHALL only display fonts that are available on the current platform.

The availability decision SHALL be expressed as a function taking the platform family as a parameter, so both outcomes are testable without `dart:io`.

#### Scenario: Windows shows only compatible fonts
- **WHEN** the settings dialog is opened on Windows
- **THEN** the font family dropdown SHALL display only: システムデフォルト, 游明朝, 游ゴシック

#### Scenario: macOS shows all fonts
- **WHEN** the settings dialog is opened on macOS
- **THEN** the font family dropdown SHALL display all font families: システムデフォルト, ヒラギノ明朝, ヒラギノ角ゴ, 游明朝, 游ゴシック

#### Scenario: iOS shows the Hiragino faces
- **WHEN** the settings dialog is opened on iOS
- **THEN** the font family dropdown SHALL display ヒラギノ明朝 and ヒラギノ角ゴ alongside the cross-platform entries

#### Scenario: Availability is resolvable without dart:io
- **WHEN** the availability function is called for an Apple platform and for a non-Apple platform
- **THEN** it returns every font family for the former and omits the Apple-only faces for the latter
