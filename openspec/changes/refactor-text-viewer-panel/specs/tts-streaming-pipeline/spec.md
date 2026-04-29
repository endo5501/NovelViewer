## ADDED Requirements

### Requirement: TtsStreamingController accepts a Reader function for provider access
The `TtsStreamingController` constructor SHALL accept a `Reader` (typedef: `T Function<T>(ProviderListenable<T>)`) for accessing Riverpod state, rather than requiring a `ProviderContainer` instance. Call sites SHALL pass `ref.read` (or an equivalent reader) so the controller does not depend on `ProviderScope.containerOf(BuildContext)`. The controller's lifetime SHALL be permitted to outlive any single `WidgetRef` because the `Reader` function delegates to the underlying long-lived `ProviderContainer` internally.

#### Scenario: Controller is constructed with ref.read
- **WHEN** `TtsStreamingController` is instantiated by `TtsControlsBar`
- **THEN** the constructor receives `read: ref.read` and the controller stores the `Reader` for later use without holding a reference to a `ProviderContainer`

#### Scenario: Controller reads providers via the injected reader
- **WHEN** the controller needs to read `TtsSession`, `TtsEngineConfig`, or other provider values during `start()`/`stop()`/`abort()`
- **THEN** it invokes the injected `Reader` function (`_read(someProvider)`) rather than calling `ProviderScope.containerOf` or holding a stored `ProviderContainer`

#### Scenario: No ProviderScope.containerOf at the call site
- **WHEN** the source of `TtsControlsBar` (or any other call site that constructs `TtsStreamingController`) is inspected
- **THEN** no `ProviderScope.containerOf(context)` invocation appears for the purpose of constructing the controller

#### Scenario: Tests inject a custom reader
- **WHEN** a unit test constructs `TtsStreamingController` with a fake `Reader` returning fixture values
- **THEN** the controller operates against those fixture values without requiring a Riverpod `ProviderContainer` to be constructed in the test setup
