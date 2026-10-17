## ADDED Requirements

### Requirement: Optional features, including each speech engine, are described by a pure capability model
The system SHALL express which optional features the running platform supports as a single value object derived by one pure function from platform flags. That function SHALL NOT read `dart:io`'s `Platform`, so it can be evaluated directly in tests for every platform. The model SHALL name features (text-to-speech, in-app update, LLM summary, on-device LLM) rather than platforms, so a consumer's reason for hiding a surface is readable at the point of use.

A feature the model names SHALL be derived on its own terms rather than from a shared platform expression, so that one feature becoming available everywhere does not carry the others with it. LLM summary is such a feature: its work is done by a server the reader runs themselves, reached over plain HTTP, and nothing in that path is platform-specific. Dart's `HttpClient` opens its own sockets rather than going through the system's URL loading layer, so the transport policy that restricts plaintext HTTP does not apply to it. What iOS does restrict is reaching a host on the local network, which needs the reader's permission, and that restriction bears on where a server may be rather than on whether the feature exists.

Speech synthesis is described per engine, because the engines do not share a platform answer. Each engine runs on a native library built per platform, and only Piper is built and verified for iOS (`piper-ios-build`): Qwen3-TTS and Irodori-TTS have no iOS library, the latter because its model exceeds the memory an iPad grants an app. The model SHALL therefore report Piper as supported everywhere, and Qwen3-TTS and Irodori-TTS as supported everywhere except iOS. Text-to-speech as a whole SHALL be reported as supported exactly when at least one engine is, so it is derived from the engines rather than stated separately.

Exporting synthesized audio to MP3 SHALL be a feature of its own, reported as unsupported on iOS: its encoder is a native library with no iOS build. The in-app update also remains unsupported on iOS.

The on-device LLM is the feature that reintroduces a genuine platform distinction, since the framework that runs the model exists only on Apple's platforms. The model SHALL report it as supported on iOS and macOS and unsupported elsewhere, which requires the derivation function to take the macOS flag as well as the iOS one.

What the model answers for the on-device LLM is only whether the platform could host the model. Whether the device is eligible, whether the reader has enabled the system intelligence feature, and whether the model has finished becoming ready SHALL NOT be part of this model. Those are determined by an asynchronous query to the native side, and two of them change while the application is running, so folding them in would make the model neither pure nor stable. `apple-on-device-llm` governs them.

Likewise, whether the engine's native library is actually present in a given build is not part of this model. On iOS the library is built separately and is not tracked by Git, so a build can lack it; that is reported when the engine is first loaded (`piper-tts-native-engine`), not by hiding the feature.

#### Scenario: Desktop platforms support every optional feature
- **WHEN** the capability model is derived for a desktop platform
- **THEN** text-to-speech with all three engines, audio export, in-app update and LLM summary are all reported as supported

#### Scenario: iOS supports speech with Piper only
- **WHEN** the capability model is derived for iOS
- **THEN** text-to-speech and the Piper engine are reported as supported
- **AND** the Qwen3-TTS and Irodori-TTS engines, audio export and in-app update are reported as unsupported
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
- **THEN** the on-device LLM is reported as supported, and text-to-speech, the engines, audio export, in-app update and LLM summary keep the answers they have on other desktop platforms

#### Scenario: The model is evaluated without touching the platform
- **WHEN** the derivation function is called from a unit test with an explicit platform flag
- **THEN** it returns the capability set for that flag, regardless of the platform the test itself runs on

## REMOVED Requirements

### Requirement: Optional features are described by a pure capability model
**Reason**: It treated speech synthesis as one platform-wide feature and required it to be unsupported on iOS. Since `ios-tts-piper` the Piper engine runs on iOS while Qwen3-TTS and Irodori-TTS do not, so speech is described per engine and the iOS scenario no longer holds.
**Migration**: Replaced by "Optional features, including each speech engine, are described by a pure capability model", which keeps every other feature's answer and scenario and adds the per-engine and audio-export answers.
