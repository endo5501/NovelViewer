## MODIFIED Requirements

### Requirement: iOS build prerequisites and constraints are documented
Building for iOS requires Xcode's iOS platform component in addition to the SDK; without it the build fails with `iOS ... is not installed` even though `xcodebuild -showsdks` lists the SDK. A debug build cannot be launched from the device's home screen at all, because it needs JIT, which iOS permits only under Flutter's tooling. Both constraints SHALL be documented for developers, along with how to supply the signing identity.

The Piper TTS native frameworks are built separately by `scripts/build_piper_ios.sh`, and a viewer-only build succeeds without them. The documentation SHALL state how to build those frameworks, that the iOS build patches piper-plus and when the patch is to be removed, and that the frameworks are optional for a viewer-only build. It SHALL also explain how to run the on-device synthesis test, including that on a physical device it must run as a profile build through `flutter drive`.

The speech.cpp framework is built separately by `scripts/build_speech_ios.sh`. It is what Irodori-TTS runs on in the iOS app. Like the Piper frameworks, it is optional for a viewer-only build, and a build without it reports the missing library when Irodori-TTS is first loaded. The documentation SHALL state:
- how to build the framework;
- that the framework stays in `ios/Frameworks/` for an app build that offers Irodori-TTS;
- how to run its on-device measurement test with a chosen quantization;
- where the measurements are written;
- that the app's data on the device is to be backed up before a device run.

The documentation SHALL also say that a `flutter drive` run on a device removes the app and its data, while installing a release build over the installed app with `xcrun devicectl device install app` keeps them.

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

#### Scenario: The speech.cpp framework is documented as part of the app build
- **WHEN** a developer reads the project's iOS build documentation
- **THEN** it names `scripts/build_speech_ios.sh` as the step that produces the framework Irodori-TTS runs on, and says to keep the framework in `ios/Frameworks/` when building the app with Irodori-TTS

#### Scenario: The speech.cpp measurement procedure is discoverable
- **WHEN** a developer reads the project's iOS build documentation
- **THEN** it gives the `flutter drive --profile` command that runs the measurement test with a chosen quantization on a connected iPad, says where the measurements are written, and says to back up the app's `Documents/` and `Library/` before the run

#### Scenario: Installing over the app keeps its data
- **WHEN** a developer reads the project's iOS build documentation
- **THEN** it states that a device run of `flutter drive` removes the app and its data, and that `xcrun devicectl device install app` with a release build installs over the app and keeps its data
