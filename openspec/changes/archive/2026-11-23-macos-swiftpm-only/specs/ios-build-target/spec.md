## ADDED Requirements

### Requirement: iOS integrates dependencies through Swift Package Manager alone
Every plugin the project depends on resolves as a Swift Package for iOS, so the iOS target SHALL NOT carry a CocoaPods integration. `ios/Podfile` SHALL NOT exist, and neither `ios/Flutter/Debug.xcconfig` nor `ios/Flutter/Release.xcconfig` SHALL include a `Pods-Runner` xcconfig. The macOS target's dependency integration is specified by the `macos-build-target` capability.

#### Scenario: No Podfile on iOS
- **WHEN** the `ios/` directory is inspected
- **THEN** no `Podfile` and no `Podfile.lock` are present

#### Scenario: xcconfigs carry no Pods include
- **WHEN** `ios/Flutter/Debug.xcconfig` and `ios/Flutter/Release.xcconfig` are inspected
- **THEN** neither includes a path under `Pods/Target Support Files`

#### Scenario: Swift Package pins are tracked
- **WHEN** the repository is inspected
- **THEN** the `xcshareddata/swiftpm/Package.resolved` file under both `ios/Runner.xcodeproj/project.xcworkspace/` and `ios/Runner.xcworkspace/` is tracked by Git

#### Scenario: The two pin files agree
- **WHEN** the two tracked `Package.resolved` files are compared
- **THEN** their contents are identical, so the resolved plugin versions do not depend on which container the project is opened through

## REMOVED Requirements

### Requirement: Swift Package Manager is the only dependency integration on iOS
**Reason**: Its last scenario required macOS to keep CocoaPods. macOS now drops CocoaPods as well, so that scenario no longer holds; the iOS part carries over unchanged under a new name.
**Migration**: The iOS scenarios move to "iOS integrates dependencies through Swift Package Manager alone". The macOS integration is specified by the `macos-build-target` capability.
