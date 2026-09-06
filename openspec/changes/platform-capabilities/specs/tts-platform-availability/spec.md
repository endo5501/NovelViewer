## MODIFIED Requirements

### Requirement: TTS availability is exposed as an overridable provider
The system SHALL expose whether text-to-speech is available on the running platform through a Riverpod provider rather than reading `dart:io`'s `Platform` at each consumer. That provider SHALL derive its value from the shared platform-capability model rather than reading the platform itself, so that the application-wide platform read occurs in exactly one place. Consumers SHALL keep watching this provider, whose name and type are unchanged, so their behaviour can be exercised for both outcomes: `dart:io`'s `Platform` cannot be overridden from a widget test, but a provider can.

#### Scenario: Consumers depend on the provider, not on Platform
- **WHEN** the widgets that gate TTS surfaces are inspected
- **THEN** none of them reads `Platform.isIOS` (or any other `Platform` flag) directly; each reads the availability provider

#### Scenario: The availability provider derives from the capability model
- **WHEN** the TTS availability provider's implementation is inspected
- **THEN** it reads the shared platform-capability provider and contains no `Platform` access of its own

#### Scenario: Availability can be overridden in tests
- **WHEN** a widget test wraps the tree in a `ProviderScope` overriding the availability provider with `false`
- **THEN** the gated widgets behave as they would on a platform without TTS support

#### Scenario: TTS is unavailable on iOS
- **WHEN** the provider's value is resolved on iOS
- **THEN** it reports that TTS is unavailable

#### Scenario: TTS remains available on desktop
- **WHEN** the provider's value is resolved on Windows, macOS or Linux
- **THEN** it reports that TTS is available

### Requirement: No reachable path to the TTS native engine when unavailable
When TTS is unavailable, the UI SHALL NOT present any control that would load the TTS native library, request microphone access, use a drag-and-drop plugin that is not registered on the platform, or edit data whose only consumer is the speech engine. Specifically, the text viewer's TTS controls bar, the settings dialog's TTS tab, and the text-selection context menu's "add to dictionary" item SHALL be absent.

#### Scenario: The controls bar is absent
- **WHEN** a text file is displayed and TTS is unavailable
- **THEN** no TTS controls bar is present in the text viewer

#### Scenario: The controls bar is present when TTS is available
- **WHEN** a text file is displayed and TTS is available
- **THEN** the TTS controls bar is present in the text viewer

#### Scenario: The TTS settings tab is absent
- **WHEN** the settings dialog is opened and TTS is unavailable
- **THEN** the dialog shows only the general and about/update tabs, and the TTS tab is neither listed nor reachable

#### Scenario: The remaining settings tabs still work
- **WHEN** the settings dialog is opened and TTS is unavailable
- **THEN** the general tab and the about/update tab display their contents and can be switched between

#### Scenario: The dictionary item is absent from the selection context menu
- **WHEN** text is selected in either horizontal or vertical display mode and the context menu is opened while TTS is unavailable
- **THEN** no "add to dictionary" item is present, because the reading dictionary exists only to instruct the speech engine

#### Scenario: The dictionary item is present when TTS is available
- **WHEN** text is selected in either horizontal or vertical display mode and the context menu is opened while TTS is available
- **THEN** the "add to dictionary" item is present, unchanged
