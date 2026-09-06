## MODIFIED Requirements

### Requirement: Text viewer panel is composed of three widget components
The text viewer SHALL be implemented as three distinct widget components: a `TextViewerPanel` shell that owns layout and file-change detection; a `TtsControlsBar` widget that owns TTS control buttons and the streaming/stored playback controller lifetime; and a `TextContentRenderer` widget that owns text rendering (horizontal/vertical mode dispatch, ruby parsing, search/TTS highlight). The shell SHALL NOT directly own controllers, scroll positions, or transient rendering state belonging to the child widgets.

On a platform where text-to-speech is unavailable, the shell SHALL omit `TtsControlsBar` entirely rather than render it in a disabled state, so that no control capable of loading the TTS native library is reachable. The decomposition rules above apply unchanged to the remaining components.

#### Scenario: Three component widgets exist
- **WHEN** the text viewer widget tree is inspected on a platform where TTS is available
- **THEN** `TtsControlsBar` and `TextContentRenderer` are present as separate widget instances under `TextViewerPanel` rather than inline build helpers on the panel state class

#### Scenario: The controls bar is omitted where TTS is unavailable
- **WHEN** the text viewer widget tree is inspected on a platform where TTS is unavailable
- **THEN** `TextContentRenderer` is present under `TextViewerPanel` and `TtsControlsBar` is absent from the tree

#### Scenario: Shell does not own component state
- **WHEN** the shell `_TextViewerPanelState` (or equivalent) is inspected
- **THEN** it does NOT declare a `TtsStreamingController`, `TtsStoredPlayerController`, `ScrollController`, or per-segment cache; only file-change subscription state and layout-level helpers are owned by the shell

#### Scenario: Component disposal releases its own resources
- **WHEN** `TtsControlsBar` is disposed (e.g., the panel is replaced)
- **THEN** the controllers and listeners it owns are released by its own `dispose`, without the shell needing to be aware
