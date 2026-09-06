## ADDED Requirements

### Requirement: TTS availability is exposed as an overridable provider
The system SHALL expose whether text-to-speech is available on the running platform through a Riverpod provider rather than reading `dart:io`'s `Platform` at each consumer. The platform read SHALL occur in exactly one place — the provider's default implementation — so that consumers can be exercised for both outcomes in tests.

#### Scenario: Consumers depend on the provider, not on Platform
- **WHEN** the widgets that gate TTS surfaces are inspected
- **THEN** none of them reads `Platform.isIOS` (or any other `Platform` flag) directly; each reads the availability provider

#### Scenario: Availability can be overridden in tests
- **WHEN** a widget test wraps the tree in a `ProviderScope` overriding the availability provider with `false`
- **THEN** the gated widgets behave as they would on a platform without TTS support

#### Scenario: TTS is unavailable on iOS
- **WHEN** the provider's default implementation is evaluated on iOS
- **THEN** it reports that TTS is unavailable

#### Scenario: TTS remains available on desktop
- **WHEN** the provider's default implementation is evaluated on Windows, macOS or Linux
- **THEN** it reports that TTS is available

### Requirement: No reachable path to the TTS native engine when unavailable
When TTS is unavailable, the UI SHALL NOT present any control that would load the TTS native library, request microphone access, or use a drag-and-drop plugin that is not registered on the platform. Specifically, the text viewer's TTS controls bar and the settings dialog's TTS tab SHALL be absent.

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

### Requirement: TTS keyboard commands are inert and unlisted when TTS is unavailable
The playback toggle shortcut SHALL NOT start synthesis when TTS is unavailable, since the controls bar that owns the toggle is not mounted. The shortcut settings list SHALL also omit that action, so the reader is not offered a rebinding for a command that can never fire.

#### Scenario: Toggle shortcut does nothing
- **WHEN** the TTS playback toggle shortcut is pressed while TTS is unavailable
- **THEN** no playback starts and no native library is loaded

#### Scenario: The TTS shortcut is not listed
- **WHEN** the shortcut settings list is displayed while TTS is unavailable
- **THEN** no row for the TTS playback toggle is present, and the other shortcut rows are unaffected

#### Scenario: The TTS shortcut is listed where TTS is available
- **WHEN** the shortcut settings list is displayed while TTS is available
- **THEN** a row for the TTS playback toggle is present

#### Scenario: The hidden binding does not block another rebinding
- **WHEN** the reader assigns to a visible action the key combination currently held by the TTS playback toggle, while TTS is unavailable
- **THEN** the assignment succeeds, because refusing it would report a conflict with a row the reader cannot see or change

#### Scenario: Conflicts between available actions are still refused
- **WHEN** the reader assigns to one visible action the key combination held by another visible action
- **THEN** the assignment is refused, whether or not TTS is available
