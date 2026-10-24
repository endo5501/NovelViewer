## REMOVED Requirements

### Requirement: Optional features, including each speech engine, are described by a pure capability model
**Reason**: Its iOS scenario states that iOS speaks with Piper only, and Irodori-TTS now runs on iOS through speech.cpp. The requirement is restated under a name that also covers the Irodori runtime and the voice library features.
**Migration**: See "Optional features, including each speech engine and its runtime, are described by a pure capability model" below, which keeps every other rule and scenario.

## ADDED Requirements

### Requirement: Optional features, including each speech engine and its runtime, are described by a pure capability model
The system SHALL express which optional features the running platform supports as a single value object derived by one pure function from platform flags. That function SHALL NOT read `dart:io`'s `Platform`, so it can be evaluated directly in tests for every platform. The model SHALL name features (text-to-speech, in-app update, LLM summary, on-device LLM) rather than platforms, so a consumer's reason for hiding a surface is readable at the point of use.

A feature the model names SHALL be derived on its own terms rather than from a shared platform expression, so that one feature becoming available everywhere does not carry the others with it. LLM summary is such a feature: its work is done by a server the reader runs themselves, reached over plain HTTP, and nothing in that path is platform-specific. Dart's `HttpClient` opens its own sockets rather than going through the system's URL loading layer, so the transport policy that restricts plaintext HTTP does not apply to it. What iOS does restrict is reaching a host on the local network, which needs the reader's permission, and that restriction bears on where a server may be rather than on whether the feature exists.

Speech synthesis is described per engine, because the engines do not share a platform answer. Each engine runs on a native library built per platform. Piper is built and verified for iOS (`piper-ios-build`). Qwen3-TTS has no iOS library. Irodori-TTS runs on iOS through speech.cpp (`speech-cpp-ios-build`), whose v4.1 Small MF model fits in the memory an iPad grants an app. The audio.cpp build used on the desktop does not fit there. The model SHALL therefore report Piper and Irodori-TTS as supported everywhere, and Qwen3-TTS as supported everywhere except iOS. Text-to-speech as a whole SHALL be reported as supported exactly when at least one engine is, so it is derived from the engines rather than stated separately.

Because Irodori-TTS runs on a different runtime per platform, the model SHALL also name the Irodori runtime of the platform: speech.cpp on iOS, audio.cpp elsewhere. Which model variants can be offered follows from that runtime (`irodori-model-variant`).

Three parts of the voice reference library depend on the platform, and each SHALL be a feature of its own, reported as unsupported on iOS and supported elsewhere:
- **Voice recording** needs a microphone permission and a recording path that are verified only on the desktop.
- **Dropping voice files** needs a drag-and-drop plugin that has no iOS build.
- **Opening the voices folder** in the platform's file manager has no equivalent on iOS, where the folder is reached through the Files app.

Exporting synthesized audio to MP3 SHALL be a feature of its own, reported as unsupported on iOS: its encoder is a native library with no iOS build. The in-app update also remains unsupported on iOS.

The on-device LLM is the feature that reintroduces a genuine platform distinction, since the framework that runs the model exists only on Apple's platforms. The model SHALL report it as supported on iOS and macOS and unsupported elsewhere, which requires the derivation function to take the macOS flag as well as the iOS one.

What the model answers for the on-device LLM is only whether the platform could host the model. Whether the device is eligible, whether the reader has enabled the system intelligence feature, and whether the model has finished becoming ready SHALL NOT be part of this model. Those are determined by an asynchronous query to the native side, and two of them change while the application is running, so folding them in would make the model neither pure nor stable. `apple-on-device-llm` governs them.

Likewise, whether the engine's native library is actually present in a given build is not part of this model. On iOS the library is built separately and is not tracked by Git, so a build can lack it; that is reported when the engine is first loaded (`piper-tts-native-engine`, `speech-cpp-native-bindings`), not by hiding the feature.

The model SHALL also name how the reader signs in for progress sync, because the two OAuth flows depend on the platform: iOS SHALL use the system authentication session, and every other platform SHALL use the desktop flow that receives the redirect on a loopback address. Whether sync is offered at all also depends on which OAuth client values the build carries, which is a property of the build rather than of the platform, so it is decided by `progress-sync-account` from this answer and not here.

#### Scenario: Desktop platforms support every optional feature
- **WHEN** the capability model is derived for a desktop platform
- **THEN** text-to-speech with all three engines, audio export, in-app update, LLM summary, voice recording, dropping voice files and opening the voices folder are all reported as supported
- **AND** the Irodori runtime is audio.cpp

#### Scenario: iOS supports speech with Piper and Irodori-TTS
- **WHEN** the capability model is derived for iOS
- **THEN** text-to-speech, the Piper engine and the Irodori-TTS engine are reported as supported, and the Irodori runtime is speech.cpp
- **AND** the Qwen3-TTS engine, audio export, in-app update, voice recording, dropping voice files and opening the voices folder are reported as unsupported
- **AND** LLM summary is reported as supported

#### Scenario: Text-to-speech follows the engines
- **WHEN** the capability model is derived for any platform
- **THEN** text-to-speech is reported as supported if and only if at least one engine is reported as supported

#### Scenario: LLM summary does not depend on the platform flag
- **WHEN** the capability model is derived for any platform
- **THEN** LLM summary is reported as supported, whatever the platform flag says

#### Scenario: The on-device LLM is supported on Apple platforms only
- **WHEN** the capability model is derived for iOS, and again for macOS
- **THEN** the on-device LLM is reported as supported in both cases

#### Scenario: The on-device LLM is unsupported elsewhere
- **WHEN** the capability model is derived for a platform that is neither iOS nor macOS
- **THEN** the on-device LLM is reported as unsupported

#### Scenario: The on-device LLM answer does not carry the other features
- **WHEN** the capability model is derived for macOS
- **THEN** the on-device LLM is reported as supported, and text-to-speech, the engines, the Irodori runtime, audio export, in-app update, LLM summary and the voice library features keep the answers they have on other desktop platforms

#### Scenario: The model is evaluated without touching the platform
- **WHEN** the derivation function is called from a unit test with an explicit platform flag
- **THEN** it returns the capability set for that flag, regardless of the platform the test itself runs on

#### Scenario: Progress sync sign-in follows the platform
- **WHEN** the capability model is derived for iOS, and again for a desktop platform
- **THEN** iOS names the system authentication session and the desktop platform names the loopback flow
