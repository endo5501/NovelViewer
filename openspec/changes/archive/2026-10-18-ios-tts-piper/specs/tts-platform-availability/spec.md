## ADDED Requirements

### Requirement: TTS availability is exposed as an overridable provider derived from the engines
The system SHALL expose whether text-to-speech is available on the running platform through a Riverpod provider rather than reading `dart:io`'s `Platform` at each consumer. That provider SHALL derive its value from the shared platform-capability model rather than reading the platform itself, so that the application-wide platform read occurs in exactly one place. Consumers SHALL keep watching this provider, whose name and type are unchanged, so their behaviour can be exercised for both outcomes: `dart:io`'s `Platform` cannot be overridden from a widget test, but a provider can.

Text-to-speech is available wherever at least one engine is, which since `ios-tts-piper` includes iOS with the Piper engine. The gating this capability defines remains in force for any platform where no engine is available, and is exercised by overriding the provider.

#### Scenario: Consumers depend on the provider, not on Platform
- **WHEN** the widgets that gate TTS surfaces are inspected
- **THEN** none of them reads `Platform.isIOS` (or any other `Platform` flag) directly; each reads the availability provider

#### Scenario: The availability provider derives from the capability model
- **WHEN** the TTS availability provider's implementation is inspected
- **THEN** it reads the shared platform-capability provider and contains no `Platform` access of its own

#### Scenario: Availability can be overridden in tests
- **WHEN** a widget test wraps the tree in a `ProviderScope` overriding the availability provider with `false`
- **THEN** the gated widgets behave as they would on a platform without TTS support

#### Scenario: TTS is available on iOS
- **WHEN** the provider's value is resolved on iOS
- **THEN** it reports that TTS is available

#### Scenario: TTS remains available on desktop
- **WHEN** the provider's value is resolved on Windows, macOS or Linux
- **THEN** it reports that TTS is available

## REMOVED Requirements

### Requirement: TTS availability is exposed as an overridable provider
**Reason**: Its scenario required TTS to be unavailable on iOS, which `ios-tts-piper` reverses by offering the Piper engine there.
**Migration**: Replaced by "TTS availability is exposed as an overridable provider derived from the engines", which keeps the provider, its name and type, and every other scenario unchanged.
