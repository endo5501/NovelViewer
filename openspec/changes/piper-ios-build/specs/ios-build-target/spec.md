## ADDED Requirements

### Requirement: Native frameworks are embedded and signed from ios/Frameworks
The iOS Runner target SHALL have a Run Script build phase that globs the xcframeworks under `ios/Frameworks/`. For each xcframework, the phase SHALL copy the `.framework` of the slice that matches the SDK being built (`$PLATFORM_NAME`) into the app's `Frameworks/` folder, and SHALL sign it with `EXPANDED_CODE_SIGN_IDENTITY`. The phase SHALL NOT hold a static list of library names, and SHALL set `alwaysOutOfDate = 1` so dependency analysis does not skip it. It SHALL fail the build when copying or signing fails.

When `ios/Frameworks/` holds no xcframework, or none has a slice for the SDK being built, the phase SHALL copy nothing and succeed, so that a checkout without the native libraries still builds the viewer.

The phase SHALL NOT take part in Swift Package Manager integration, and SHALL NOT introduce CocoaPods on iOS.

#### Scenario: A device build embeds and signs the frameworks
- **WHEN** `fvm flutter build ios` is run with `ios/Frameworks/piper_plus.xcframework` and `ios/Frameworks/onnxruntime.xcframework` present
- **THEN** the build succeeds, `Runner.app/Frameworks/piper_plus.framework/piper_plus` and `Runner.app/Frameworks/onnxruntime.framework/onnxruntime` exist, and `codesign --verify` succeeds on both

#### Scenario: A simulator build embeds the simulator slice
- **WHEN** the app is built for the iOS Simulator with the xcframeworks present
- **THEN** `Runner.app/Frameworks/` holds the simulator slice of each framework

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

## MODIFIED Requirements

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
