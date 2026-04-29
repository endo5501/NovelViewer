## ADDED Requirements

### Requirement: Text viewer panel is composed of three widget components
The text viewer SHALL be implemented as three distinct widget components: a `TextViewerPanel` shell that owns layout and file-change detection; a `TtsControlsBar` widget that owns TTS control buttons and the streaming/stored playback controller lifetime; and a `TextContentRenderer` widget that owns text rendering (horizontal/vertical mode dispatch, ruby parsing, search/TTS highlight). The shell SHALL NOT directly own controllers, scroll positions, or transient rendering state belonging to the child widgets.

#### Scenario: Three component widgets exist
- **WHEN** the text viewer widget tree is inspected
- **THEN** `TtsControlsBar` and `TextContentRenderer` are present as separate widget instances under `TextViewerPanel` rather than inline build helpers on the panel state class

#### Scenario: Shell does not own component state
- **WHEN** the shell `_TextViewerPanelState` (or equivalent) is inspected
- **THEN** it does NOT declare a `TtsStreamingController`, `TtsStoredPlayerController`, `ScrollController`, or per-segment cache; only file-change subscription state and layout-level helpers are owned by the shell

#### Scenario: Component disposal releases its own resources
- **WHEN** `TtsControlsBar` is disposed (e.g., the panel is replaced)
- **THEN** the controllers and listeners it owns are released by its own `dispose`, without the shell needing to be aware

### Requirement: Cross-component state goes through Riverpod
State that more than one component needs to read or react to (e.g., `TtsAudioState`, `TtsPlaybackState`, the active engine type, the current selected file, search query) SHALL be accessed via Riverpod providers. Components SHALL NOT pass shared mutable state through constructor parameters or shared parent fields for the purpose of inter-component synchronization.

#### Scenario: TTS audio state is shared via provider
- **WHEN** `TtsControlsBar` and `TextContentRenderer` both need to react to `TtsAudioState` changes (e.g., to render controls and to render the highlight)
- **THEN** both widgets observe the change via `ref.watch(ttsAudioStateProvider(filePath))` independently rather than receiving the state via shared widget parameters

#### Scenario: Selected file change drives shell-side detection only
- **WHEN** the user selects a different file
- **THEN** the shell reacts via `ref.listenManual(selectedFileProvider, ...)` registered in `initState` to load content; the children re-render via their own `ref.watch`

### Requirement: Shell stays under 200 lines
The `text_viewer_panel.dart` file SHALL contain only: the shell `ConsumerStatefulWidget`, file-change detection, layout composition (`Column`/`Stack` with the two components and the existing chrome), and any panel-scoped dialog launchers. The total line count of the shell file SHALL be ≤ 200 LOC after the refactor.

#### Scenario: Shell file size budget
- **WHEN** `lib/features/text_viewer/presentation/text_viewer_panel.dart` is measured after the refactor
- **THEN** its line count is ≤ 200 lines (significantly down from the pre-refactor 900 LOC), and the file contains no TTS-control or content-render build helpers

### Requirement: TtsControlsBar consolidates the TTS state-machine switches
The `TtsControlsBar` widget SHALL contain a SINGLE switch (or pattern match) over the `(TtsAudioState, TtsPlaybackState)` pair that decides which buttons (play, pause, stop, edit, export, delete) and indicators (loading, waiting) are rendered. The state-machine logic SHALL NOT be duplicated across other widgets in the text viewer.

#### Scenario: Single state-machine switch in TtsControlsBar
- **WHEN** the source of `TtsControlsBar` is inspected
- **THEN** exactly one switch/pattern over `(TtsAudioState, TtsPlaybackState)` is present, covering the cases used by the audit's state walk (none → generating → ready → playing → paused → stopped, plus waiting)

#### Scenario: Inline state switches removed from shell
- **WHEN** the source of `TextViewerPanel` (shell) is inspected
- **THEN** no inline switch over `(TtsAudioState, TtsPlaybackState)` exists; that responsibility belongs to `TtsControlsBar`

### Requirement: Parsed segments cached via Riverpod by content hash
The text viewer SHALL cache the result of parsing text content into `TextSegment` lists via a Riverpod-provided `ParsedSegmentsCache`. The cache key SHALL be the content's SHA-256 hash. The `TextContentRenderer` widget SHALL NOT maintain a per-instance `_segmentsCache` field; multiple renderer instances rendering the same content SHALL share the same cached result. The cache SHALL bound its memory usage with an LRU eviction policy of at most 50 entries.

#### Scenario: Same content reuses parsed segments
- **WHEN** two `TextContentRenderer` instances render text with the same content (and therefore the same hash)
- **THEN** the underlying parser is invoked once, and both renderers receive the same cached `List<TextSegment>` from `ParsedSegmentsCache`

#### Scenario: Different content triggers fresh parse
- **WHEN** a renderer renders text whose hash is not in the cache
- **THEN** the parser is invoked and the result is stored under that hash

#### Scenario: Cache evicts least-recently-used entries past the limit
- **WHEN** more than 50 distinct content hashes have been parsed over the application's lifetime
- **THEN** the least-recently-used entries are evicted to keep memory usage bounded

#### Scenario: Cache survives widget rebuild
- **WHEN** a renderer widget is rebuilt (e.g., due to theme change) and re-renders the same content
- **THEN** the cache returns the previously parsed segments without re-invoking the parser

### Requirement: File change detection is registered in initState
The `TextViewerPanel` shell SHALL register a `ref.listenManual(selectedFileProvider, ...)` (or equivalent) in `initState` to react to selected-file changes. The shell SHALL NOT mutate state from `build` based on the selected file or schedule post-frame callbacks from `build` to drive content loading.

#### Scenario: Listener registered in initState fires on first build
- **WHEN** the shell is mounted with a non-null `selectedFile`
- **THEN** `listenManual` (with `fireImmediately: true` or equivalent bootstrap) triggers content loading without `build` mutating the shell's state

#### Scenario: File change triggers reload
- **WHEN** the user selects a different file while the panel is visible
- **THEN** the listener registered in `initState` reacts to the provider change and the shell loads the new content; no `build`-time state mutation occurs

#### Scenario: No build-time mutation of the shell state
- **WHEN** the shell's `build` method is inspected
- **THEN** it does not assign to `_lastViewedFilePath`, schedule `addPostFrameCallback`, or otherwise mutate state outside `setState`
