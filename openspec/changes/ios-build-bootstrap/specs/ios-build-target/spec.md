## ADDED Requirements

### Requirement: iPad-only device family
The iOS build SHALL target iPad exclusively. `TARGETED_DEVICE_FAMILY` in `ios/Runner.xcodeproj/project.pbxproj` SHALL be `"2"` for every build configuration.

#### Scenario: Device family is iPad only
- **WHEN** `ios/Runner.xcodeproj/project.pbxproj` is inspected
- **THEN** every `TARGETED_DEVICE_FAMILY` assignment is `"2"` and none is `"1"` or `"1,2"`

#### Scenario: iPad orientations remain unrestricted
- **WHEN** `ios/Runner/Info.plist` is inspected
- **THEN** `UISupportedInterfaceOrientations~ipad` lists portrait, portrait-upside-down, landscape-left and landscape-right

### Requirement: Library is reachable from the Files app
The iOS build SHALL expose its `Documents` directory to the Files app so the reader can inspect, add and remove novel files without the app. `ios/Runner/Info.plist` SHALL declare `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace`, both true.

#### Scenario: File sharing keys are declared
- **WHEN** `ios/Runner/Info.plist` is inspected
- **THEN** `UIFileSharingEnabled` is `true` and `LSSupportsOpeningDocumentsInPlace` is `true`

#### Scenario: The library folder is what the reader sees
- **WHEN** the app has started at least once on iOS and the Files app is opened
- **THEN** a `NovelViewer` folder appears under the app's directory, holding the novel folders

### Requirement: Swift Package Manager is the only dependency integration on iOS
Every plugin the project depends on resolves as a Swift Package for iOS, so the iOS target SHALL NOT carry a CocoaPods integration. `ios/Podfile` SHALL NOT exist, and neither `ios/Flutter/Debug.xcconfig` nor `ios/Flutter/Release.xcconfig` SHALL include a `Pods-Runner` xcconfig. The macOS target's CocoaPods integration is out of scope and SHALL remain unchanged.

#### Scenario: No Podfile on iOS
- **WHEN** the `ios/` directory is inspected
- **THEN** no `Podfile` and no `Podfile.lock` are present

#### Scenario: xcconfigs carry no Pods include
- **WHEN** `ios/Flutter/Debug.xcconfig` and `ios/Flutter/Release.xcconfig` are inspected
- **THEN** neither includes a path under `Pods/Target Support Files`

#### Scenario: Swift Package pins are tracked
- **WHEN** the repository is inspected
- **THEN** `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` is tracked by Git

#### Scenario: macOS keeps CocoaPods
- **WHEN** the `macos/` directory is inspected
- **THEN** `macos/Podfile` and `macos/Podfile.lock` are still present and unchanged

### Requirement: Signing identity is kept out of the repository
The developer's `DEVELOPMENT_TEAM` SHALL NOT be committed. The iOS xcconfigs SHALL optionally include an untracked `ios/Flutter/Local.xcconfig` that supplies it, and the build configuration SHALL remain valid when that file is absent.

#### Scenario: xcconfigs include the local override
- **WHEN** `ios/Flutter/Debug.xcconfig` and `ios/Flutter/Release.xcconfig` are inspected
- **THEN** each contains an optional include of `Local.xcconfig`

#### Scenario: The local override is ignored by Git
- **WHEN** `.gitignore` rules are evaluated against `ios/Flutter/Local.xcconfig`
- **THEN** the path is ignored

#### Scenario: No team identifier in the project file
- **WHEN** `ios/Runner.xcodeproj/project.pbxproj` is inspected
- **THEN** it contains no `DEVELOPMENT_TEAM` assignment with a non-empty value

### Requirement: The iOS project tracks Flutter's required migrations
The committed `ios/` project SHALL be the state Flutter's toolchain produces for the pinned SDK, including the UIScene lifecycle migration and Swift Package Manager integration, so that a build does not rewrite tracked files.

#### Scenario: UIScene lifecycle is adopted
- **WHEN** `ios/Runner/AppDelegate.swift` and `ios/Runner/Info.plist` are inspected
- **THEN** the app delegate registers plugins through the implicit-engine delegate and `Info.plist` declares `UIApplicationSceneManifest`

#### Scenario: A build leaves the project unchanged
- **WHEN** an iOS build is run against a clean working tree
- **THEN** no tracked file under `ios/` is modified by the build

### Requirement: iOS toolchain prerequisites are documented
Building for iOS requires Xcode's iOS platform component in addition to the SDK; without it the build fails with `iOS ... is not installed` even though `xcodebuild -showsdks` lists the SDK. This prerequisite SHALL be documented for developers.

#### Scenario: Prerequisite is discoverable
- **WHEN** a developer reads the project's build documentation
- **THEN** it states that the Xcode iOS platform component must be installed before an iOS build can run
