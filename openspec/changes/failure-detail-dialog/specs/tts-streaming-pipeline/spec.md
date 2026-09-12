## MODIFIED Requirements

### Requirement: Failure is reported to the user via a localized notification

When `TtsStreamingController.start()` returns `failed`, the calling UI (`TtsControlsBar._startStreaming`) SHALL display a localized snackbar informing the user that audio generation failed. The notification SHALL use a localized message key present in all supported locales (`ja`, `en`, `zh`). When `start()` returns any value other than `failed` (including `stopped`), no failure snackbar SHALL be shown.

失敗の原因文言が得られる場合、通知はローカライズされた見出しに続けてその原因文言を提示 SHALL する。原因文言はネイティブ層が動的に生成する文字列であり、翻訳対象と SHALL NOT。原因文言が得られない場合、通知は見出しのみを提示 SHALL する。

`TtsStreamingController` SHALL 失敗判定を行う時点で `TtsSession` から失敗理由を取得し、`start()` の呼び出し元が参照できる形で保持する。`TtsSession` は `start()` の終了処理で dispose されるため、呼び出し元が dispose 後のセッションへ問い合わせることに依存 SHALL NOT。`TtsStartOutcome` の列挙値は変更 SHALL NOT。

通知は共通の失敗通知経路を通して表示 SHALL する。すなわち、ユーザーが閉じるまで残り、詳細アクションを備える。呼び出し元は見出しを headline、原因文言を cause とする `FailureReport` を構築 SHALL する。合成失敗は例外ではなく `TtsStartOutcome` として戻るため、スタックトレースは省略 SHALL する。

診断情報には、失敗時刻、アプリケーションバージョン、TTSエンジン種別、モデル名、対象ファイル名を含める SHALL。

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

#### Scenario: The failure notification persists and offers details
- **WHEN** `start()` が `failed` を返して失敗スナックバーが表示される
- **THEN** スナックバーは既定の表示時間が経過しても表示されたままであり、詳細アクションを備える

#### Scenario: The report carries the synthesis diagnostics
- **WHEN** 合成が失敗し、詳細ダイアログを開いてコピーする
- **THEN** コピーされたテキストに失敗時刻、アプリケーションバージョン、TTSエンジン種別、モデル名、対象ファイル名が含まれる

#### Scenario: No stack trace section appears
- **WHEN** 合成失敗の詳細ダイアログをコピーする
- **THEN** スタックトレースの節は出力に現れない
