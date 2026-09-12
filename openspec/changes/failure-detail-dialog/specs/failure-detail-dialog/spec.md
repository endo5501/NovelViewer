## ADDED Requirements

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

The system SHALL present a failure notification as a snackbar that does not disappear on its own. The snackbar SHALL remain visible until the user dismisses it or a newer failure replaces it.

The snackbar SHALL offer a close affordance (`showCloseIcon`) and exactly one action labelled for opening the details. `SnackBar` accepts a single action, so the close affordance SHALL NOT be implemented as a second action.

The snackbar body SHALL be the headline alone when the report carries no cause, and the headline joined with the cause when it carries one.

Before showing a failure snackbar the system SHALL remove the snackbar currently displayed, so consecutive failures do not queue up behind one another.

Success notifications SHALL be unaffected and SHALL continue to dismiss themselves after the default duration.

#### Scenario: The failure snackbar outlives the default duration

- **WHEN** a failure snackbar is shown and no user interaction occurs
- **THEN** the snackbar is still visible after the default snackbar duration has elapsed

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
