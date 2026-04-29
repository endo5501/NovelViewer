## ADDED Requirements

### Requirement: TtsEngineConfig sealed type
The system SHALL define `TtsEngineConfig` as a sealed class with two subclasses: `Qwen3EngineConfig` and `PiperEngineConfig`. Each subclass SHALL carry only the fields that the corresponding TTS engine consumes. Common fields (`modelDir`, `sampleRate`) SHALL live on the base class; engine-specific fields (Qwen3: `languageId`, `refWavPath`; Piper: `dicDir`, `lengthScale`, `noiseScale`, `noiseW`) SHALL live on their respective subclasses.

#### Scenario: Qwen3 config carries Qwen3-only fields
- **WHEN** a `Qwen3EngineConfig` instance is constructed with `modelDir`, `sampleRate`, `languageId`, and optional `refWavPath`
- **THEN** the instance exposes those fields and does not have Piper-only fields (e.g., `lengthScale`)

#### Scenario: Piper config carries Piper-only fields
- **WHEN** a `PiperEngineConfig` instance is constructed with `modelDir`, `sampleRate`, `dicDir`, `lengthScale`, `noiseScale`, `noiseW`
- **THEN** the instance exposes those fields and does not have Qwen3-only fields (e.g., `languageId`)

#### Scenario: Sealed switch is exhaustive
- **WHEN** code uses a Dart `switch` on a `TtsEngineConfig` value
- **THEN** the compiler SHALL require both `Qwen3EngineConfig` and `PiperEngineConfig` arms (sealed exhaustiveness)

### Requirement: Resolve engine config from providers
The system SHALL provide a `TtsEngineConfig.resolveFromRef(WidgetRef ref, TtsEngineType type)` factory and an equivalent `TtsEngineConfig.resolveFromReader(T Function<T>(ProviderListenable<T>) read, TtsEngineType type)` that builds the appropriate subclass from the current Riverpod state. The factory SHALL use `read` (not `watch`) for the underlying providers so the call does not subscribe the caller to rebuilds.

#### Scenario: Resolve Qwen3 config
- **WHEN** `resolveFromRef(ref, TtsEngineType.qwen3)` is called and the Qwen3 providers expose `modelDir="/m/q"`, `sampleRate=24000`, `languageId=2058`, `refWavPath="/voice.wav"`
- **THEN** the result is a `Qwen3EngineConfig` with those exact values

#### Scenario: Resolve Piper config
- **WHEN** `resolveFromRef(ref, TtsEngineType.piper)` is called and the Piper providers expose `modelDir="/m/p"`, `sampleRate=22050`, `dicDir="/dic"`, `lengthScale=1.0`, `noiseScale=0.667`, `noiseW=0.8`
- **THEN** the result is a `PiperEngineConfig` with those exact values

#### Scenario: Resolution does not subscribe to rebuilds
- **WHEN** `resolveFromRef(ref, ...)` is called inside a widget build method
- **THEN** the underlying providers are read via `ref.read` (not `ref.watch`), so updates to those providers do not trigger rebuilds of the calling widget

### Requirement: Single point of engine config construction
Code paths that previously assembled engine-specific parameter sets inline (text viewer panel, TTS edit dialog) SHALL obtain a `TtsEngineConfig` exclusively via the resolve factory. Engine-specific `if/else` blocks that build parameter sets manually SHALL NOT exist outside `TtsEngineConfig` and its `resolveFromReader`/`resolveFromRef` implementation.

#### Scenario: Text viewer panel uses the resolver
- **WHEN** the text viewer panel needs to start the streaming controller
- **THEN** it obtains a `TtsEngineConfig` via `TtsEngineConfig.resolveFromRef(ref, engineType)` and passes it to `TtsStreamingController.start(...)`, with no engine-specific `if/else` block in the panel

#### Scenario: Edit dialog uses the resolver
- **WHEN** the TTS edit dialog needs to load a model or synthesize a segment
- **THEN** it obtains a `TtsEngineConfig` via `TtsEngineConfig.resolveFromRef(ref, engineType)` and passes it to the edit controller, with no engine-specific `if/else` block in the dialog
