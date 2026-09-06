## Purpose

Gates every text-to-speech surface behind a single overridable Riverpod provider instead of scattered `dart:io` platform checks, so that on a platform without TTS support (iOS) no control capable of loading the TTS native library, requesting microphone access, or invoking a desktop-only drag-and-drop plugin is reachable: the text viewer's TTS controls bar, the settings dialog's 読み上げ tab, and the text-selection context menu's "add to dictionary" item are all absent, and the TTS playback binding is not registered at all, so the key combination falls through to any other handler and stays out of the way of other rebindings. The availability provider derives its value from the shared platform-capability model rather than reading `Platform` itself.

## Requirements

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

### Requirement: TTS keyboard commands are inert and unlisted when TTS is unavailable
The playback toggle binding SHALL NOT be registered at all when TTS is unavailable. Leaving it registered would consume the key press and do nothing, since the controls bar that owns the toggle is not mounted — and the reader could neither see that binding nor change it, because the shortcut settings list omits the row too. Unregistered, the combination falls through to whatever else may handle it.

#### Scenario: The binding is not registered
- **WHEN** the shortcut map is built while TTS is unavailable
- **THEN** it contains no entry for the TTS playback toggle, so the combination is left for another handler rather than consumed

#### Scenario: Toggle shortcut does nothing
- **WHEN** the TTS playback toggle shortcut is pressed while TTS is unavailable
- **THEN** no playback starts, no toggle request is issued, and no native library is loaded

#### Scenario: The TTS shortcut is not listed
- **WHEN** the shortcut settings list is displayed while TTS is unavailable
- **THEN** no row for the TTS playback toggle is present, and the other shortcut rows are unaffected

#### Scenario: The TTS shortcut is listed where TTS is available
- **WHEN** the shortcut settings list is displayed while TTS is available
- **THEN** a row for the TTS playback toggle is present, and pressing its binding issues a toggle request

#### Scenario: The hidden binding does not block another rebinding
- **WHEN** the reader assigns to a visible action the key combination currently held by the TTS playback toggle, while TTS is unavailable
- **THEN** the assignment succeeds, because refusing it would report a conflict with a row the reader cannot see or change

#### Scenario: Conflicts between available actions are still refused
- **WHEN** the reader assigns to one visible action the key combination held by another visible action
- **THEN** the assignment is refused, whether or not TTS is available
