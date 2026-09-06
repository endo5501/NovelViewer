## Purpose

Describes the optional features the running platform supports as a pure capability model derived from platform flags, so that availability is a property of a named feature rather than a platform check scattered through the code. The platform is read in exactly one place — the default implementation of the capability provider — and is distributed to consumers as per-feature boolean Riverpod providers, which lets a widget test exercise either outcome by overriding a provider. Where a feature is unavailable it presents no surface at all rather than a disabled one, registers no keyboard binding that would swallow a key press for an invisible action, and — for the features reached through a single service entry point — refuses the work there too, so no network request is issued even if a guardless surface is added later.

## Requirements

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
Where an optional feature is unavailable, the application SHALL NOT present a control that would invoke it. A control SHALL be absent from the widget tree rather than merely disabled, and a keyboard binding for it SHALL NOT be registered — a registered binding would consume the key press and do nothing, for an action the reader can neither see nor rebind.

Where the feature is reached through a single service entry point, that entry point SHALL refuse the work as well, so that a surface added later without a guard cannot reach it. Hiding the control alone is not sufficient there. This applies to the two features that would otherwise open a network connection: the update check and the summary analysis runner.

Speech synthesis has no such entry point — its native library is loaded lazily by several data-layer classes that hold no reference to the capability model — so it is protected by the absence of every invoking surface instead, which is why the keyboard binding matters there.

#### Scenario: No control is presented
- **WHEN** a screen that would host a control for an unavailable feature is rendered
- **THEN** that control is absent from the widget tree, not merely disabled

#### Scenario: No keyboard binding is registered
- **WHEN** the shortcut map is built while a feature that owns an action is unavailable
- **THEN** the map holds no entry for that action, and its key combination falls through to any other handler

#### Scenario: A network-reaching entry point refuses the work
- **WHEN** the update check or the analysis runner is invoked directly on a platform where its feature is unavailable, bypassing the UI
- **THEN** it returns without performing the work and without issuing a network request
