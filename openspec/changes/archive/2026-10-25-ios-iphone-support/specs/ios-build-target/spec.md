## REMOVED Requirements

### Requirement: iPad-only device family
**Reason**: The iOS build now targets iPhone as well as iPad.
**Migration**: Replaced by "iPhone and iPad device family", which sets `TARGETED_DEVICE_FAMILY` to `"1,2"`, restricts the iPhone to portrait and keeps the iPad's four orientations.

## ADDED Requirements

### Requirement: iPhone and iPad device family
The iOS build SHALL target both iPhone and iPad. `TARGETED_DEVICE_FAMILY` in `ios/Runner.xcodeproj/project.pbxproj` SHALL be `"1,2"` for every build configuration.

On iPhone the app SHALL run in portrait only. `UISupportedInterfaceOrientations` in `ios/Runner/Info.plist`, the list iOS applies to an iPhone, SHALL contain `UIInterfaceOrientationPortrait` and no other orientation. A landscape iPhone is 852pt wide but only about 393pt tall, so the width-based shell layout would put the wide layout, with its search column, into a screen too short for it; the reader uses the phone upright, so the app does not offer that layout there at all.

On iPad the orientations SHALL remain unrestricted: `UISupportedInterfaceOrientations~ipad` SHALL list portrait, portrait-upside-down, landscape-left and landscape-right, so restricting the iPhone does not change how the app behaves on an iPad.

#### Scenario: Device family is iPhone and iPad
- **WHEN** `ios/Runner.xcodeproj/project.pbxproj` is inspected
- **THEN** every `TARGETED_DEVICE_FAMILY` assignment is `"1,2"`

#### Scenario: iPhone is portrait only
- **WHEN** `ios/Runner/Info.plist` is inspected
- **THEN** `UISupportedInterfaceOrientations` lists `UIInterfaceOrientationPortrait` and no landscape or upside-down orientation

#### Scenario: Rotating an iPhone keeps the app upright
- **WHEN** the app is running on an iPhone and the phone is turned to landscape
- **THEN** the app stays in portrait

#### Scenario: iPad orientations remain unrestricted
- **WHEN** `ios/Runner/Info.plist` is inspected
- **THEN** `UISupportedInterfaceOrientations~ipad` lists portrait, portrait-upside-down, landscape-left and landscape-right
