## MODIFIED Requirements

### Requirement: Optional features are described by a pure capability model
The system SHALL express which optional features the running platform supports as a single value object derived by one pure function from platform flags. That function SHALL NOT read `dart:io`'s `Platform`, so it can be evaluated directly in tests for every platform. The model SHALL name features (text-to-speech, in-app update, LLM summary) rather than platforms, so a consumer's reason for hiding a surface is readable at the point of use.

A feature the model names SHALL be derived on its own terms rather than from a shared platform expression, so that one feature becoming available everywhere does not carry the others with it. LLM summary is such a feature: its work is done by a server the reader runs themselves, reached over plain HTTP, and nothing in that path is platform-specific. Dart's `HttpClient` opens its own sockets rather than going through the system's URL loading layer, so the transport policy that restricts plaintext HTTP does not apply to it. What iOS does restrict is reaching a host on the local network, which needs the reader's permission, and that restriction bears on where a server may be rather than on whether the feature exists.

Speech synthesis and the in-app update remain unsupported on iOS, so the model SHALL continue to report a platform-dependent answer for those two.

#### Scenario: Desktop platforms support every optional feature
- **WHEN** the capability model is derived for a desktop platform
- **THEN** text-to-speech, in-app update and LLM summary are all reported as supported

#### Scenario: iOS supports LLM summary but neither speech nor self-update
- **WHEN** the capability model is derived for iOS
- **THEN** LLM summary is reported as supported
- **AND** text-to-speech and in-app update are both reported as unsupported

#### Scenario: LLM summary does not depend on the platform flag
- **WHEN** the capability model is derived for any platform
- **THEN** LLM summary is reported as supported, whatever the platform flag says

#### Scenario: The model is evaluated without touching the platform
- **WHEN** the derivation function is called from a unit test with an explicit platform flag
- **THEN** it returns the capability set for that flag, regardless of the platform the test itself runs on
