## MODIFIED Requirements

### Requirement: Native frameworks are embedded and signed from ios/Frameworks
The iOS Runner target SHALL have a Run Script build phase that globs the xcframeworks under `ios/Frameworks/`. For each xcframework, the phase SHALL copy the `.framework` of the slice that matches the SDK being built (`$PLATFORM_NAME`) into the app's `Frameworks/` folder, and SHALL sign it with `EXPANDED_CODE_SIGN_IDENTITY`. The phase SHALL NOT hold a static list of library names, and SHALL set `alwaysOutOfDate = 1` so dependency analysis does not skip it. It SHALL fail the build when copying or signing fails.

When `ios/Frameworks/` holds no xcframework, or none has a slice for the SDK being built, the phase SHALL copy nothing and succeed, so that a checkout without the native libraries still builds the viewer.

The phase SHALL also remove from the app's `Frameworks/` folder every framework it embedded in an earlier build whose xcframework is no longer under `ios/Frameworks/`. Xcode's incremental build reuses the app bundle and the phase declares no outputs Xcode could clean, so without this a removed or renamed xcframework would leave its old, signed binary in the app: a build meant to have no Piper library would still load one. The phase SHALL record what it embedded in the target's temporary build directory, not in the app bundle, and SHALL NOT remove a framework it did not embed, such as Flutter's own.

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

#### Scenario: A removed xcframework does not survive an incremental build
- **WHEN** the app is built with `ios/Frameworks/piper_plus.xcframework`, the xcframework is then removed, and the app is built again without cleaning
- **THEN** `Runner.app/Frameworks/` no longer holds `piper_plus.framework`, and Flutter's frameworks are still present
