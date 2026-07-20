# tts-engine-config (delta)

## MODIFIED Requirements

### Requirement: TtsEngineConfig sealed type
The system SHALL define `TtsEngineConfig` as a sealed class with three subclasses: `Qwen3EngineConfig`, `PiperEngineConfig`, and `IrodoriEngineConfig`. Each subclass SHALL carry only the fields that the corresponding TTS engine consumes. Common fields (`modelDir`, `sampleRate`) SHALL live on the base class; engine-specific fields (Qwen3: `languageId`, `refWavPath`; Piper: `dicDir`, `lengthScale`, `noiseScale`, `noiseW`; Irodori: `refWavPath`, `speakerGuidanceScale`, `captionGuidanceScale`, `numInferenceSteps`) SHALL live on their respective subclasses. The `IrodoriEngineConfig.modelLoadKey` SHALL include only the engine type and `modelDir`, so that synthesis-time parameters (refWavPath, guidance scales, steps, caption) do not trigger model reloads.

#### Scenario: Qwen3 config carries Qwen3-only fields
- **WHEN** a `Qwen3EngineConfig` instance is constructed with `modelDir`, `sampleRate`, `languageId`, and optional `refWavPath`
- **THEN** the instance exposes those fields and does not have Piper-only fields (e.g., `lengthScale`)

#### Scenario: Piper config carries Piper-only fields
- **WHEN** a `PiperEngineConfig` instance is constructed with `modelDir`, `sampleRate`, `dicDir`, `lengthScale`, `noiseScale`, `noiseW`
- **THEN** the instance exposes those fields and does not have Qwen3-only fields (e.g., `languageId`)

#### Scenario: Irodori config carries Irodori-only fields
- **WHEN** an `IrodoriEngineConfig` instance is constructed with `modelDir`, `sampleRate: 48000`, optional `refWavPath`, `speakerGuidanceScale`, `captionGuidanceScale`, `numInferenceSteps`
- **THEN** the instance exposes those fields and does not have Qwen3-only fields (e.g., `languageId`) or Piper-only fields (e.g., `dicDir`)

#### Scenario: Irodori modelLoadKey excludes synthesis-time parameters
- **WHEN** two `IrodoriEngineConfig` instances share the same `modelDir` but differ in `refWavPath`, guidance scales, or steps
- **THEN** their `modelLoadKey` values are equal (no model reload between them)

#### Scenario: Sealed switch is exhaustive
- **WHEN** code uses a Dart `switch` on a `TtsEngineConfig` value
- **THEN** the compiler SHALL require `Qwen3EngineConfig`, `PiperEngineConfig`, and `IrodoriEngineConfig` arms (sealed exhaustiveness)

### Requirement: Resolve engine config from providers
The system SHALL provide a `TtsEngineConfig.resolveFromRef(WidgetRef ref, TtsEngineType type)` factory and an equivalent `TtsEngineConfig.resolveFromReader(T Function<T>(ProviderListenable<T>) read, TtsEngineType type)` that builds the appropriate subclass from the current Riverpod state, covering all three engine types. The factory SHALL use `read` (not `watch`) for the underlying providers so the call does not subscribe the caller to rebuilds. For `TtsEngineType.irodori`, the factory SHALL resolve the model directory, the shared voice reference (same `ttsRefWavPathProvider` / voice library as Qwen3), and the persisted Irodori synthesis parameters.

#### Scenario: Resolve Qwen3 config
- **WHEN** `resolveFromRef(ref, TtsEngineType.qwen3)` is called and the Qwen3 providers expose `modelDir="/m/q"`, `sampleRate=24000`, `languageId=2058`, `refWavPath="/voice.wav"`
- **THEN** the result is a `Qwen3EngineConfig` with those exact values

#### Scenario: Resolve Piper config
- **WHEN** `resolveFromRef(ref, TtsEngineType.piper)` is called and the Piper providers expose `modelDir="/m/p"`, `sampleRate=22050`, `dicDir="/dic"`, `lengthScale=1.0`, `noiseScale=0.667`, `noiseW=0.8`
- **THEN** the result is a `PiperEngineConfig` with those exact values

#### Scenario: Resolve Irodori config
- **WHEN** `resolveFromRef(ref, TtsEngineType.irodori)` is called and the Irodori providers expose `modelDir="/m/i"`, voice reference `"/voices/ref.wav"`, `speakerGuidanceScale=5.0`, `captionGuidanceScale=3.0`, `numInferenceSteps=40`
- **THEN** the result is an `IrodoriEngineConfig` with those exact values and `sampleRate=48000`

#### Scenario: Resolution does not subscribe to rebuilds
- **WHEN** `resolveFromRef(ref, ...)` is called inside a widget build method
- **THEN** the underlying providers are read via `ref.read` (not `ref.watch`), so updates to those providers do not trigger rebuilds of the calling widget
