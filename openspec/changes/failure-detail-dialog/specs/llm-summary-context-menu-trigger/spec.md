## MODIFIED Requirements

### Requirement: Analysis failure notification reports the failed-file count

When an analysis triggered from the context menu fails because one or more in-scope source files could not be extracted, the system SHALL dismiss the progress modal and show a snackbar whose message states how many files failed, that no summary was saved, that re-running retries only the failed files, and what the underlying error was. When the analysis instead fails because no facts could be extracted at all, the snackbar SHALL name the analyzed word and state that no summary was saved. Both messages SHALL be localized for every supported display language (ja / en / zh).

Any other failure — one not carrying a per-file extraction outcome, such as a storage error raised before or around the extraction loop — SHALL continue to use the existing generic failure message.

The localized messages SHALL NOT embed the underlying error themselves. The error reaches the snackbar as the report's cause, which the shared notification path appends to the headline, so it appears exactly once. `llmAnalysis_failed` SHALL take no placeholder and `llmAnalysis_partialFailure` SHALL take only the failed-file count.

The failed-file count SHALL NOT be persisted; it is conveyed to the user only through this notification.

The failure notification SHALL be shown through the shared failure notification path, so it stays up long enough to be read and carries a details action. The runner SHALL catch the failure with its stack trace (`catch (e, st)`) and build a `FailureReport` whose headline is the message selected by the rules above and whose stack trace is the captured one.

The report's cause SHALL contribute only what the localized headline does not already say, because the shared path appends it to the headline on screen. For a partial extraction failure the cause SHALL be the first file's error; for a run that yielded no facts there SHALL be no cause; for any other failure the cause SHALL be the exception's string form. A typed failure's Dart class name SHALL NOT reach the snackbar body.

The report's diagnostics SHALL carry the time of the failure, the application version, the configured LLM provider kind, the configured model name, the analyzed word, the resolved inclusive episode bound (`covered up to`), and the source file name. The bound is recorded rather than the `AnalysisScope` value because `run()` receives only the resolved integer. They SHALL NOT carry the configured endpoint URL.

The success notification SHALL be unchanged and SHALL continue to dismiss itself automatically.

#### Scenario: Partial extraction failure reports the count and the cause

- **WHEN** an analysis of "アリス" over five in-scope files fails because two of them could not be extracted, the first with a connection error
- **THEN** the progress modal SHALL be dismissed and a snackbar SHALL be shown whose message conveys that two files failed, that no summary was saved, and what the connection error was

#### Scenario: A run that extracted no facts names the word

- **WHEN** an analysis of "ボブ" fails because no in-scope file yielded any facts
- **THEN** a snackbar SHALL be shown naming "ボブ" and stating that no summary was saved, and the generic failure wording SHALL NOT be used

#### Scenario: A successful analysis keeps the existing message

- **WHEN** an analysis completes with every in-scope file extracted
- **THEN** the existing success snackbar naming the analyzed word SHALL be shown, unchanged, and it SHALL dismiss itself after the default duration

#### Scenario: An unclassified failure keeps the generic message

- **WHEN** an analysis fails with an error that carries no per-file extraction outcome (e.g. the novel's database is locked)
- **THEN** the existing generic failure snackbar SHALL be shown, without a failed-file count

#### Scenario: The failure message is localized

- **WHEN** the display language is `en` or `zh` and an analysis fails with a failed-file count
- **THEN** the snackbar message SHALL be rendered from that language's localization, not from the Japanese string

#### Scenario: The failure notification persists and offers details

- **WHEN** an analysis fails and the resulting snackbar is shown
- **THEN** the snackbar SHALL still be visible after the default snackbar duration has elapsed and SHALL offer a details action

#### Scenario: The report carries the analysis diagnostics

- **WHEN** an analysis of "アリス" resolved to the episode bound 40 over the file `040_chapter.txt` fails while the configured provider is `ollama`
- **THEN** the detail dialog's copied text SHALL contain the time, the application version, `ollama`, the configured model name, `アリス`, the bound 40, and `040_chapter.txt`

#### Scenario: A typed failure keeps its class name off the body

- **WHEN** an analysis fails because no in-scope file yielded any facts
- **THEN** the snackbar body names the analyzed word and SHALL NOT contain `LlmAnalysisNoFactsFailure`

#### Scenario: A partial failure shows the cause, not the wrapper

- **WHEN** an analysis fails with a partial extraction failure whose first error is a connection error
- **THEN** the snackbar body contains that connection error and SHALL NOT contain `LlmAnalysisPartialFailure`

#### Scenario: The underlying error appears exactly once

- **WHEN** an analysis fails with a partial extraction failure whose first error is a connection error, and the resulting snackbar body is read
- **THEN** the connection error text SHALL appear once, not once from the localized message and again from the appended cause

#### Scenario: The stack trace reaches the report

- **WHEN** an analysis fails with an exception raised inside the pipeline
- **THEN** the detail dialog SHALL present the stack trace captured at the catch site
