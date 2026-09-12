## Purpose

Present a failure to the reader as a persistent, dismissible notification that carries enough diagnostic detail to be copied into a bug report, while withholding endpoints, filesystem locations, and credentials from everything it renders.
## Requirements
### Requirement: Failure reports carry diagnostics alongside the headline

The system SHALL provide a single value type, `FailureReport`, that carries everything a failure notification needs: a localized `headline`, an optional raw `cause` string, an optional `stackTrace`, and a `diagnostics` map of ordered key/value pairs. Every user-facing failure surface routed through the shared notification path SHALL construct one.

The `diagnostics` map SHALL preserve insertion order so the rendered and copied output reads in the order the producer chose. Diagnostic keys SHALL be fixed English identifiers and SHALL NOT be localized, because they are read by whoever receives a bug report rather than by the reader operating the app.

Producers SHALL supply the application version as a diagnostic. The shared notification path SHALL NOT read it from a provider itself, so that the widgets stay testable without a Riverpod container.

#### Scenario: A report preserves diagnostic ordering

- **WHEN** a `FailureReport` is built with diagnostics inserted in the order `time`, `app version`, `provider`, `model`
- **THEN** iterating the diagnostics yields those keys in that same order

#### Scenario: A report without a cause or stack trace is valid

- **WHEN** a `FailureReport` is built with only a headline and diagnostics
- **THEN** the report is constructed successfully and its `cause` and `stackTrace` are null

### Requirement: The failure snackbar persists until dismissed

The system SHALL present a failure notification as a snackbar that stays up long enough to be read and acted on, rather than clearing after the default few seconds. It SHALL remain visible until the user dismisses it, a newer failure replaces it, or a bounded display time elapses.

The display time SHALL be bounded. `ScaffoldMessenger` shows one snackbar at a time and queues the rest, so a notification that never clears itself would swallow every later notification in the application until the reader happened to dismiss it. `SnackBar` defaults `persist` to `action != null` and then ignores `duration` entirely, so the system SHALL set `persist` to false explicitly.

The snackbar SHALL offer a close affordance (`showCloseIcon`) and exactly one action labelled for opening the details. `SnackBar` accepts a single action, so the close affordance SHALL NOT be implemented as a second action.

The system SHALL allow a caller to supply the `ScaffoldMessenger` the snackbar is shown through. A modal surface owns no `Scaffold` of its own, so a bar shown through the page's messenger renders beneath the modal barrier, where neither the action nor the close icon can be reached.

The snackbar body SHALL be the headline alone when the report carries no cause, and the headline joined with the cause when it carries one.

Before showing a failure snackbar the system SHALL remove the snackbar currently displayed, so consecutive failures do not queue up behind one another.

Success notifications SHALL be unaffected and SHALL continue to dismiss themselves after the default duration.

#### Scenario: The failure snackbar outlives the default duration

- **WHEN** a failure snackbar is shown and no user interaction occurs
- **THEN** the snackbar is still visible after the default snackbar duration has elapsed

#### Scenario: A queued ordinary notification is not swallowed

- **WHEN** an ordinary snackbar is raised while a failure snackbar is up, and no user interaction occurs
- **THEN** the failure snackbar eventually clears on its own and the queued notification is shown

#### Scenario: A modal surface shows through its own messenger

- **WHEN** a failure is reported from a modal dialog that hands in its own `ScaffoldMessenger`
- **THEN** the snackbar is shown through that messenger, above the modal barrier, and its details action can be tapped

#### Scenario: The close affordance dismisses it

- **WHEN** the user taps the close icon on a failure snackbar
- **THEN** the snackbar is dismissed and no detail dialog is opened

#### Scenario: A second failure replaces the first

- **WHEN** a failure snackbar is visible and a second failure is reported
- **THEN** the first snackbar is removed and the second is shown in its place, rather than the second waiting in the queue

#### Scenario: The body joins the headline with the cause

- **WHEN** a failure snackbar is shown for a report whose headline is a localized string and whose cause is `ClientException: connection refused`
- **THEN** the snackbar body contains both the headline and `ClientException: connection refused`

#### Scenario: The body is the headline alone when no cause exists

- **WHEN** a failure snackbar is shown for a report whose `cause` is null
- **THEN** the snackbar body contains only the headline

### Requirement: The details action opens a readable diagnostic dialog

The snackbar's action SHALL open a dialog presenting the report's diagnostics, cause, and stack trace. The dialog content SHALL be scrollable and its text SHALL be selectable, so a long stack trace can be read and partially copied by hand.

The dialog SHALL be opened through the root `NavigatorState` captured when the snackbar was shown, guarded by a mounted check, rather than through a `BuildContext` captured by the action closure. The action closure receives no context, and the widget that triggered the failure may be disposed while the snackbar is still visible.

The dialog SHALL offer a copy action and a close action. The dialog title and all three button labels SHALL be localized in every supported display language (ja / en / zh).

#### Scenario: Tapping details opens the dialog

- **WHEN** the user taps the details action on a failure snackbar
- **THEN** a dialog is shown containing the report's diagnostics, cause, and stack trace

#### Scenario: The dialog opens after the triggering widget is gone

- **WHEN** the widget that reported the failure has been removed from the tree while the failure snackbar is still visible, and the user then taps the details action
- **THEN** the dialog is still shown and no context-related error is raised

#### Scenario: Dialog chrome is localized

- **WHEN** the dialog title, details action, copy action, and close action labels are resolved
- **THEN** a non-empty translation exists for each in `app_ja.arb`, `app_en.arb`, and `app_zh.arb`

### Requirement: The report copies as one plain-text block

The dialog's copy action SHALL place the entire report on the clipboard as plain text and SHALL confirm the copy to the user.

The copied text SHALL be composed as: one `key: value` line per diagnostic in insertion order, then a blank line and the cause, then a blank line and the stack trace. A diagnostic whose value is null or empty SHALL be omitted entirely rather than written with an empty value. The cause section SHALL be omitted when the report carries no cause, and the stack-trace section SHALL be omitted when it carries no stack trace.

The copied text SHALL NOT be wrapped in a code fence, because the destination is not necessarily a Markdown-rendering surface.

#### Scenario: A full report renders every section

- **WHEN** a report with diagnostics, a cause, and a stack trace is rendered to copy text
- **THEN** the result is the diagnostic lines, a blank line, the cause, a blank line, and the stack trace, in that order

#### Scenario: Absent sections are omitted

- **WHEN** a report with diagnostics but no cause and no stack trace is rendered to copy text
- **THEN** the result contains only the diagnostic lines and no trailing blank sections

#### Scenario: Empty diagnostics are dropped

- **WHEN** a report whose `file` diagnostic is an empty string is rendered to copy text
- **THEN** no `file:` line appears in the result

#### Scenario: Copying confirms to the user

- **WHEN** the user taps the copy action in the detail dialog
- **THEN** the rendered text is written to the clipboard and a confirmation is shown

### Requirement: Rendered failure text withholds endpoints and filesystem locations

Every text the system renders from a report — the snackbar body and the copied detail text alike — SHALL be redacted of endpoints and filesystem locations before it is shown.

Withholding the endpoint from the diagnostics is not enough on its own: the raw `cause` and `stackTrace` are produced elsewhere and can carry the same values. An HTTP client's exception string embeds the request URI, an OpenAI-compatible error embeds the response body, and a native TTS failure embeds the reference audio's absolute path. Redaction SHALL happen at the rendering step rather than at each producer, so a failure surface added later cannot forget it.

Redaction SHALL NOT alter text that carries neither a URL nor an absolute path.

Redaction SHALL replace any URL, from its scheme through to the next whitespace, with a fixed placeholder, removing host, port, path and any credentials carried in the userinfo. It SHALL replace the directory portion of any absolute filesystem path, POSIX or Windows, with a fixed placeholder while keeping the final path segment, so the file remains identifiable but its location does not.

Redaction SHALL also withhold a host reported outside a URL. A `SocketException` names the host separately, as `address = <host>`, which no URL rule would see, so the value following that label SHALL be replaced, as SHALL any bare IPv4 literal. A three-part version string SHALL NOT be mistaken for one.

#### Scenario: A connection error's URI is withheld

- **WHEN** a report whose cause is `ClientException: Connection refused, uri=http://192.168.1.20:11434/api/generate` is rendered
- **THEN** neither the host, the port, nor the path appears in the rendered text, and a placeholder stands in their place

#### Scenario: Credentials inside a URL are withheld

- **WHEN** a report whose cause contains `https://user:secret@example.com/v1/chat` is rendered
- **THEN** neither `user` nor `secret` appears in the rendered text

#### Scenario: A reference audio path keeps only its file name

- **WHEN** a report whose cause is `could not open audio input: /Users/someone/voices/sample.wav` is rendered
- **THEN** the rendered text contains `sample.wav` but not `/Users/someone/voices`

#### Scenario: A Windows path is redacted too

- **WHEN** a report whose cause contains `C:\Users\someone\voices\sample.wav` is rendered
- **THEN** the rendered text contains `sample.wav` but not `C:\Users\someone`

#### Scenario: An address reported outside a URL is withheld

- **WHEN** a report whose cause is `ClientException with SocketException: Operation timed out …, address = 192.168.99.99, port = 56676, uri=http://192.168.99.99:11434/v1/chat` is rendered
- **THEN** the address does not appear anywhere in the rendered text, while the error number and the port remain

#### Scenario: A version string is not mistaken for an address

- **WHEN** a report carrying the diagnostic `app version: 1.8.4+19` is rendered
- **THEN** that line is unchanged

#### Scenario: The snackbar body is redacted as well

- **WHEN** a failure snackbar is shown for a report whose cause carries a URI
- **THEN** the snackbar body carries the placeholder, not the URI

#### Scenario: A stack trace is redacted

- **WHEN** a report whose stack trace carries a `file:///Users/someone/...` frame is rendered
- **THEN** that frame's location does not appear verbatim in the rendered text

### Requirement: Diagnostics exclude endpoints and secrets

The diagnostics of an LLM failure report SHALL NOT include the configured endpoint URL (`LlmConfig.baseUrl`), because a self-hosted endpoint carries the user's private network address and the report is intended to be pasted into a bug report.

The diagnostics SHALL NOT include an API key or any other credential under any key.

The provider kind and the model name SHALL be included, so the configuration under which the failure occurred remains identifiable without the endpoint.

#### Scenario: The endpoint is absent from the copied text

- **WHEN** an LLM failure report is produced while the configured provider is `ollama` with a `baseUrl` of `http://192.168.1.20:11434`
- **THEN** the rendered copy text contains neither `192.168.1.20` nor the `baseUrl` value under any key

#### Scenario: Provider and model survive

- **WHEN** the same report is rendered to copy text
- **THEN** the result contains a `provider` line naming `ollama` and a `model` line naming the configured model
