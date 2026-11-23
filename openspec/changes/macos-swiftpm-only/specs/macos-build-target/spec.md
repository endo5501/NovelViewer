## Purpose

Defines how the committed `macos/` project integrates its dependencies: every plugin resolves through Swift Package Manager, and the project carries no CocoaPods integration, while the native-library embedding keeps working without it.

## ADDED Requirements

### Requirement: Swift Package Manager is the only dependency integration on macOS
Every plugin the project depends on resolves as a Swift Package for macOS, so the macOS target SHALL NOT carry a CocoaPods integration. `macos/Podfile` and `macos/Podfile.lock` SHALL NOT exist, the macOS Flutter xcconfigs SHALL NOT include a `Pods-Runner` xcconfig, the workspace SHALL NOT reference `Pods/Pods.xcodeproj`, and the Xcode project SHALL NOT link a `Pods_*` framework or run a `[CP]` build phase.

#### Scenario: No Podfile on macOS
- **WHEN** the `macos/` directory is inspected
- **THEN** no `Podfile` and no `Podfile.lock` are present

#### Scenario: xcconfigs carry no Pods include
- **WHEN** `macos/Flutter/Flutter-Debug.xcconfig` and `macos/Flutter/Flutter-Release.xcconfig` are inspected
- **THEN** neither includes a path under `Pods/Target Support Files`

#### Scenario: Workspace has no Pods project
- **WHEN** `macos/Runner.xcworkspace/contents.xcworkspacedata` is inspected
- **THEN** it does not reference `Pods.xcodeproj`

#### Scenario: Xcode project has no CocoaPods residue
- **WHEN** `macos/Runner.xcodeproj/project.pbxproj` is inspected
- **THEN** it contains no `Pods_Runner` or `Pods_RunnerTests` framework reference, no `Pods-Runner` xcconfig reference, and no `[CP]` build phase

#### Scenario: Plugins still resolve through Swift Package Manager
- **WHEN** `macos/Runner.xcodeproj/project.pbxproj` is inspected
- **THEN** the Runner target links `FlutterGeneratedPluginSwiftPackage`

#### Scenario: Building does not run CocoaPods
- **WHEN** the macOS app is built with `scripts/build_app.sh macos`
- **THEN** the build does not run `pod install` and does not warn that the project still has a CocoaPods integration

### Requirement: Native-library embedding survives without CocoaPods
The Runner target's "Embed Native Libraries" build phase, which was originally added by the Podfile's `post_install` hook, SHALL remain in `macos/Runner.xcodeproj/project.pbxproj` as a committed build phase so that `macos/Frameworks/*.dylib` keep being embedded and signed with no CocoaPods step.

#### Scenario: Phase is still in the project
- **WHEN** `macos/Runner.xcodeproj/project.pbxproj` is inspected
- **THEN** the Runner target lists an "Embed Native Libraries" shell script phase that copies `macos/Frameworks/*.dylib`

#### Scenario: Built app still contains the dylibs
- **WHEN** the macOS app is built after the migration and `scripts/test/verify_macos_bundle.sh` is run
- **THEN** the verification passes
