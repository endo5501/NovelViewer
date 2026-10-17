## Purpose

Defines the committed state of the `ios/` project so NovelViewer builds and runs as an iPad-only app: an iPad-exclusive device family with unrestricted orientations, a `Documents` library the reader can reach from the Files app, a declared local-network usage description so the reader can be asked for permission to reach a self-hosted LLM server, Swift Package Manager as the sole dependency integration (no CocoaPods on iOS, with macOS untouched), a signing identity kept out of the repository behind an untracked `Local.xcconfig`, Flutter's required project migrations tracked so a build never rewrites tracked files, native frameworks under `ios/Frameworks/` embedded and signed without a static list (and without breaking a build that has none), and documented build prerequisites and constraints.

## Requirements

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

### Requirement: Local network access is declared
The LLM server a reader's summaries are produced by is one they run themselves, which on a tablet means a host on the local network. iOS gates reaching such a host behind the reader's permission, and the system has nothing to put in that prompt without a purpose string. `ios/Runner/Info.plist` SHALL declare `NSLocalNetworkUsageDescription` with a non-empty string saying what the connection is for.

Without it the failure is silent and misleading: the settings section is present, the address the reader entered is correct, and every analysis fails with a connection error that names no cause. The transport policy that restricts plaintext HTTP is a separate matter and needs no key here, because the requests are sent through `dart:io`'s `HttpClient`, which opens its own sockets rather than going through the URL loading system that policy is enforced in.

#### Scenario: The usage description is declared
- **WHEN** `ios/Runner/Info.plist` is inspected
- **THEN** `NSLocalNetworkUsageDescription` is present and its value is a non-empty string

#### Scenario: No transport-policy exception is added for it
- **WHEN** `ios/Runner/Info.plist` is inspected
- **THEN** it declares no App Transport Security exception, since the HTTP client in use is not subject to that policy

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
- **THEN** the `xcshareddata/swiftpm/Package.resolved` file under both `ios/Runner.xcodeproj/project.xcworkspace/` and `ios/Runner.xcworkspace/` is tracked by Git

#### Scenario: The two pin files agree
- **WHEN** the two tracked `Package.resolved` files are compared
- **THEN** their contents are identical, so the resolved plugin versions do not depend on which container the project is opened through

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

### Requirement: iOS build prerequisites and constraints are documented
Building for iOS requires Xcode's iOS platform component in addition to the SDK; without it the build fails with `iOS ... is not installed` even though `xcodebuild -showsdks` lists the SDK. A debug build cannot be launched from the device's home screen at all, because it needs JIT, which iOS permits only under Flutter's tooling. Both constraints SHALL be documented for developers, along with how to supply the signing identity.

The Piper TTS native frameworks are built separately by `scripts/build_piper_ios.sh`, and a viewer-only build succeeds without them. The documentation SHALL state how to build those frameworks, that the iOS build patches piper-plus and when the patch is to be removed, and that the frameworks are optional for a viewer-only build. It SHALL also explain how to run the on-device synthesis test, including that on a physical device it must run as a profile build through `flutter drive`.

#### Scenario: Platform component prerequisite is discoverable
- **WHEN** a developer reads the project's build documentation
- **THEN** it states that the Xcode iOS platform component must be installed before an iOS build can run

#### Scenario: The release-only launch constraint is discoverable
- **WHEN** a developer reads the project's build documentation
- **THEN** it states that installing on a device for ordinary use requires a release build, and that a debug build launched from the home screen only reports that it cannot start

#### Scenario: The signing setup is discoverable
- **WHEN** a developer reads the project's build documentation
- **THEN** it explains how to create the untracked `Local.xcconfig` with a development team, and that a free provisioning profile expires after seven days

#### Scenario: The native TTS framework build is discoverable
- **WHEN** a developer reads the project's iOS build documentation
- **THEN** it names `scripts/build_piper_ios.sh` as the step that produces the Piper frameworks, explains the piper-plus patch and its removal condition, and states that the iOS build succeeds without the frameworks when only the viewer is needed

#### Scenario: The on-device synthesis test procedure is discoverable
- **WHEN** a developer reads the project's iOS build documentation
- **THEN** it gives the command that runs the synthesis test on the Simulator and, as a profile build through `flutter drive`, on a connected iPad, and says where the measurements are written

### Requirement: Native frameworks are embedded and signed from ios/Frameworks
The iOS Runner target SHALL have a Run Script build phase that globs the xcframeworks under `ios/Frameworks/`. For each xcframework, the phase SHALL copy the `.framework` of the slice that matches the SDK being built (`$PLATFORM_NAME`) into the app's `Frameworks/` folder, and SHALL sign it with `EXPANDED_CODE_SIGN_IDENTITY`. The phase SHALL NOT hold a static list of library names, and SHALL set `alwaysOutOfDate = 1` so dependency analysis does not skip it. It SHALL fail the build when copying or signing fails.

When `ios/Frameworks/` holds no xcframework, or none has a slice for the SDK being built, the phase SHALL copy nothing and succeed, so that a checkout without the native libraries still builds the viewer.

The phase SHALL NOT take part in Swift Package Manager integration, and SHALL NOT introduce CocoaPods on iOS.

#### Scenario: A device build embeds and signs the frameworks
- **WHEN** `fvm flutter build ios` is run with `ios/Frameworks/piper_plus.xcframework` present
- **THEN** the build succeeds, `Runner.app/Frameworks/piper_plus.framework/piper_plus` exists, and `codesign --verify` succeeds on it

#### Scenario: A simulator build embeds the simulator slice
- **WHEN** the app is built for the iOS Simulator with the xcframeworks present
- **THEN** `Runner.app/Frameworks/` holds the simulator slice of each xcframework

#### Scenario: A build without xcframeworks still succeeds
- **WHEN** an iOS build is run with no xcframework under `ios/Frameworks/`
- **THEN** the embed phase copies nothing, exits successfully, and the build succeeds

#### Scenario: The phase holds no static library list
- **WHEN** the embed phase definition in `project.pbxproj` is inspected
- **THEN** `inputPaths` and `outputPaths` are both empty, no individual framework name appears in `shellScript`, and `alwaysOutOfDate = 1` is set

#### Scenario: The project file still parses
- **WHEN** `xcodebuild -list -project ios/Runner.xcodeproj` is run after the phase is added
- **THEN** it lists the targets without a parse error

### Requirement: The app's minimum OS is not below that of any embedded framework
For every build configuration, the iOS Runner's `IPHONEOS_DEPLOYMENT_TARGET` SHALL be at least the `MinimumOSVersion` declared by every slice of every xcframework under `ios/Frameworks/`. The embed phase ships these frameworks in every iOS build. A framework that requires a newer OS than the app is rejected by App Store and TestFlight validation, and cannot be loaded at all on an older OS.

#### Scenario: The deployment target covers every framework
- **WHEN** `IPHONEOS_DEPLOYMENT_TARGET` in `project.pbxproj` is compared with the `MinimumOSVersion` in the `Info.plist` of every framework under `ios/Frameworks/`
- **THEN** no build configuration's deployment target is lower than any framework's minimum OS
