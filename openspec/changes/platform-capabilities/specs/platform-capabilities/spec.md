## ADDED Requirements

### Requirement: Optional features are described by a pure capability model
The system SHALL express which optional features the running platform supports as a single value object derived by one pure function from platform flags. That function SHALL NOT read `dart:io`'s `Platform`, so it can be evaluated directly in tests for every platform. The model SHALL name features (text-to-speech, in-app update, LLM summary) rather than platforms, so a consumer's reason for hiding a surface is readable at the point of use.

#### Scenario: Desktop platforms support every optional feature
- **WHEN** the capability model is derived for a desktop platform
- **THEN** text-to-speech, in-app update and LLM summary are all reported as supported

#### Scenario: iOS supports none of the optional features
- **WHEN** the capability model is derived for iOS
- **THEN** text-to-speech, in-app update and LLM summary are all reported as unsupported

#### Scenario: The model is evaluated without touching the platform
- **WHEN** the derivation function is called from a unit test with an explicit platform flag
- **THEN** it returns the capability set for that flag, regardless of the platform the test itself runs on

### Requirement: The platform is read in exactly one place and distributed as per-feature providers
The application SHALL read `dart:io`'s `Platform` for the purpose of feature availability in exactly one place: the default implementation of the capability provider. Each optional feature SHALL be exposed to its consumers as its own boolean Riverpod provider derived from that model. Consumers SHALL depend on the per-feature provider and SHALL NOT read `Platform` themselves, so that both outcomes can be exercised in widget tests — `dart:io`'s `Platform` cannot be overridden from a test, but a provider can.

#### Scenario: Each feature has its own boolean provider
- **WHEN** a surface belonging to an optional feature needs to know whether it may be shown
- **THEN** it watches a boolean provider named for that feature, not the capability model itself and not `Platform`

#### Scenario: Gated surfaces do not read the platform
- **WHEN** the widgets and services gated by an optional feature are inspected
- **THEN** none of them reads `Platform.isIOS` or any other `Platform` flag

#### Scenario: Availability can be overridden in tests
- **WHEN** a widget test wraps the tree in a `ProviderScope` overriding a per-feature provider with `false`
- **THEN** the gated surfaces behave as they would on a platform without that feature

#### Scenario: Overriding the capability model reaches every derived provider
- **WHEN** a test overrides the capability provider with a model in which one feature is unsupported
- **THEN** that feature's boolean provider reports `false` and the other features' providers are unaffected

### Requirement: An unavailable feature presents no surface and issues no request
Where an optional feature is unavailable, the application SHALL NOT present a control that would invoke it, and the service behind the feature SHALL NOT perform the work the feature implies — in particular it SHALL NOT open a network connection on the feature's behalf. Hiding the control alone is not sufficient: the entry point SHALL refuse the work as well, so that a surface added later without a guard cannot reach it.

#### Scenario: No control is presented
- **WHEN** a screen that would host a control for an unavailable feature is rendered
- **THEN** that control is absent from the widget tree, not merely disabled

#### Scenario: The entry point refuses the work
- **WHEN** the service behind an unavailable feature is invoked directly, bypassing the UI
- **THEN** it returns without performing the feature's work and without issuing a network request
