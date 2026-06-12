## ADDED Requirements

### Requirement: Synthesis failure is surfaced and never masquerades as completed

The streaming pipeline SHALL distinguish a genuine synthesis/model-load failure from a user-initiated stop and from normal completion. Within the generation/playback loop, when `ensureModelLoaded` returns `false` or `synthesize` returns `null` while `_stopped` is `false`, the system SHALL treat this as a failure (not a stop). On `start()` completion the system SHALL set the episode status as follows: if the run was stopped by the user, the status SHALL be `partial`; if the run failed and at least one stored segment has audio data, the status SHALL be `partial`; if the run failed and no stored segment has audio data, the system SHALL delete the episode record so that the file's derived `TtsAudioState` reverts to `none`; otherwise (normal completion) the status SHALL be `completed`. The system SHALL NOT mark an episode `completed` when a failure occurred. The `start()` method SHALL return a `TtsStartOutcome` value (`completed`, `stopped`, or `failed`) describing the result so callers can react to failures. A failure that kept some audio and a failure with no audio both return `failed` (the difference is reflected in the persisted episode status, not the outcome).

The system MUST rely on `_stopped` being set before `abort()` during `stop()`, which guarantees that any `false`/`null` returned because of an abort is observed with `_stopped` already `true`; therefore a `false`/`null` observed while `_stopped` is `false` is always a real engine failure.

#### Scenario: Model-load failure with no audio deletes the episode
- **WHEN** `start()` is called, no prior audio exists, and `ensureModelLoaded` returns `false` while the user has not stopped
- **THEN** no segment is marked, the episode record is deleted, the derived `TtsAudioState` for the file becomes `none`, and `start()` returns `failed`

#### Scenario: Mid-stream synthesis failure with partial audio yields partial
- **WHEN** `start()` generates and stores audio for the first 2 of 5 segments, then `synthesize` returns `null` for segment 2 while the user has not stopped
- **THEN** the episode status is set to `partial`, the 2 stored segments are preserved, and `start()` returns `failed`

#### Scenario: User stop is not treated as a failure
- **WHEN** the user stops the pipeline mid-generation so that `_stopped` is `true` before the in-flight `synthesize` completes with `null`
- **THEN** the episode status is set to `partial`, no episode is deleted, and `start()` returns `stopped` (not `failed`)

#### Scenario: Successful run completes normally
- **WHEN** `start()` generates audio for all segments without any failure or stop
- **THEN** the episode status is set to `completed` and `start()` returns `completed`

### Requirement: Failure is reported to the user via a localized notification

When `TtsStreamingController.start()` returns `failed`, the calling UI (`TtsControlsBar._startStreaming`) SHALL display a localized snackbar informing the user that audio generation failed. The notification SHALL use a localized message key present in all supported locales (`ja`, `en`, `zh`) and SHALL NOT expose the native engine error string. When `start()` returns any value other than `failed` (including `stopped`), no failure snackbar SHALL be shown.

#### Scenario: Failure shows a localized snackbar
- **WHEN** `_startStreaming` awaits `start()` and the returned outcome is `failed`
- **THEN** a snackbar with the localized "audio generation failed" message is shown via `ScaffoldMessenger`

#### Scenario: Stop does not show a failure snackbar
- **WHEN** `_startStreaming` awaits `start()` and the returned outcome is `stopped`
- **THEN** no failure snackbar is shown

#### Scenario: Localization parity
- **WHEN** the failure message key is resolved
- **THEN** a non-empty translation exists in `app_ja.arb`, `app_en.arb`, and `app_zh.arb`

### Requirement: Native engine error messages are logged

`TtsSession` SHALL log the native error string carried by isolate responses at WARNING level via its `Logger` rather than discarding it. In `ensureModelLoaded`, when the received `ModelLoadedResponse` has a non-null `error`, the session SHALL emit a WARNING log carrying that error before resolving the load result. In `synthesize`, when the received `SynthesisResultResponse` has a non-null `error` (or null audio), the session SHALL emit a WARNING log carrying the error before completing the synthesis result with `null`. Logging SHALL NOT change the existing return contract (`ensureModelLoaded` still returns `bool`, `synthesize` still returns the response or `null`).

#### Scenario: Model-load error is logged
- **WHEN** `ensureModelLoaded` receives a `ModelLoadedResponse(success: false, error: "model file not found")`
- **THEN** a WARNING-level `LogRecord` carrying "model file not found" is emitted on the session's logger and `ensureModelLoaded` returns `false`

#### Scenario: Synthesis error is logged
- **WHEN** `synthesize` receives a `SynthesisResultResponse(error: "vocab load failed", audio: null)`
- **THEN** a WARNING-level `LogRecord` carrying "vocab load failed" is emitted on the session's logger and `synthesize` completes with `null`

#### Scenario: Successful responses do not log a warning
- **WHEN** `ensureModelLoaded` receives `ModelLoadedResponse(success: true)` and `synthesize` receives a response with audio and no error
- **THEN** no WARNING-level error log is emitted by the session for those responses
