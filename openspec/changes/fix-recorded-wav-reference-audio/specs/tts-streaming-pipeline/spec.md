## MODIFIED Requirements

### Requirement: Native engine error messages are logged

`TtsSession` SHALL log the native error string carried by isolate responses at WARNING level via its `Logger` rather than discarding it. In `ensureModelLoaded`, when the received `ModelLoadedResponse` has a non-null `error`, the session SHALL emit a WARNING log carrying that error before resolving the load result. In `synthesize`, when the received `SynthesisResultResponse` has a non-null `error` (or null audio), the session SHALL emit a WARNING log carrying the error before completing the synthesis result with `null`. Logging SHALL NOT change the existing return contract (`ensureModelLoaded` still returns `bool`, `synthesize` still returns the response or `null`).

加えて、`TtsSession` SHALL 直近の合成失敗の原因文言を保持し、`synthesize` が `null` を返した呼び出し元がそれを取得できるようにする。保持される値は次のとおりとする。

- `SynthesisResultResponse` が非 null の `error` を伴って失敗した場合、その `error` 文字列
- ワーカー死亡により合成が完了しなかった場合、その死亡理由の文字列
- 原因文言が得られない失敗（audio が null で `error` も null）の場合、`null`

`synthesize` が成功した場合、保持されている原因文言 SHALL クリアされる。この保持は既存の戻り値契約を変更 SHALL NOT（`synthesize` は引き続きレスポンスまたは `null` を返す）。

#### Scenario: Model-load error is logged
- **WHEN** `ensureModelLoaded` receives a `ModelLoadedResponse(success: false, error: "model file not found")`
- **THEN** a WARNING-level `LogRecord` carrying "model file not found" is emitted on the session's logger and `ensureModelLoaded` returns `false`

#### Scenario: Synthesis error is logged
- **WHEN** `synthesize` receives a `SynthesisResultResponse(error: "vocab load failed", audio: null)`
- **THEN** a WARNING-level `LogRecord` carrying "vocab load failed" is emitted on the session's logger and `synthesize` completes with `null`

#### Scenario: Successful responses do not log a warning
- **WHEN** `ensureModelLoaded` receives `ModelLoadedResponse(success: true)` and `synthesize` receives a response with audio and no error
- **THEN** no WARNING-level error log is emitted by the session for those responses

#### Scenario: Synthesis error is retained for the caller
- **WHEN** `synthesize` receives a `SynthesisResultResponse(error: "unsupported WAV encoding (need PCM16, PCM24, or float32)", audio: null)`
- **THEN** `synthesize` completes with `null` かつ セッションが保持する直近の失敗理由が "unsupported WAV encoding (need PCM16, PCM24, or float32)" を含む

#### Scenario: Worker death reason is retained for the caller
- **WHEN** `synthesize` の待機中にワーカーが死亡し `WorkerDiedResponse(error: "isolate crashed")` を受信する
- **THEN** `synthesize` completes with `null` かつ セッションが保持する直近の失敗理由が "isolate crashed" を含む

#### Scenario: Successful synthesis clears the retained reason
- **WHEN** 直前の `synthesize` が失敗して理由が保持されている状態で、次の `synthesize` が音声を伴うレスポンスで成功する
- **THEN** セッションが保持する直近の失敗理由は `null` になる

### Requirement: Failure is reported to the user via a localized notification

When `TtsStreamingController.start()` returns `failed`, the calling UI (`TtsControlsBar._startStreaming`) SHALL display a localized snackbar informing the user that audio generation failed. The notification SHALL use a localized message key present in all supported locales (`ja`, `en`, `zh`). When `start()` returns any value other than `failed` (including `stopped`), no failure snackbar SHALL be shown.

失敗の原因文言が得られる場合、通知はローカライズされた見出しに続けてその原因文言を提示 SHALL する。原因文言はネイティブ層が動的に生成する文字列であり、翻訳対象と SHALL NOT。原因文言が得られない場合、通知は見出しのみを提示 SHALL する。

`TtsStreamingController` SHALL 失敗判定を行う時点で `TtsSession` から失敗理由を取得し、`start()` の呼び出し元が参照できる形で保持する。`TtsSession` は `start()` の終了処理で dispose されるため、呼び出し元が dispose 後のセッションへ問い合わせることに依存 SHALL NOT。`TtsStartOutcome` の列挙値は変更 SHALL NOT。

#### Scenario: Failure shows a localized snackbar
- **WHEN** `_startStreaming` awaits `start()` and the returned outcome is `failed`
- **THEN** a snackbar with the localized "audio generation failed" message is shown via `ScaffoldMessenger`

#### Scenario: Stop does not show a failure snackbar
- **WHEN** `_startStreaming` awaits `start()` and the returned outcome is `stopped`
- **THEN** no failure snackbar is shown

#### Scenario: Localization parity
- **WHEN** the failure message key is resolved
- **THEN** a non-empty translation exists in `app_ja.arb`, `app_en.arb`, and `app_zh.arb`

#### Scenario: Failure with a native cause appends the cause
- **WHEN** 合成が "unsupported WAV encoding (need PCM16, PCM24, or float32)" で失敗し `start()` が `failed` を返す
- **THEN** スナックバーにローカライズされた見出しと "unsupported WAV encoding (need PCM16, PCM24, or float32)" の両方を含むメッセージが表示される

#### Scenario: Failure without a cause shows the headline only
- **WHEN** `start()` が `failed` を返し、コントローラが保持する失敗理由が `null` である
- **THEN** スナックバーにローカライズされた見出しのみが表示される

#### Scenario: Failure reason survives session disposal
- **WHEN** `start()` が失敗して戻り、その終了処理で `TtsSession` が dispose されている
- **THEN** 呼び出し元は `TtsStreamingController` から失敗理由を取得できる
