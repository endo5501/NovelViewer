## ADDED Requirements

### Requirement: Analysis failure notification reports the failed-file count

When an analysis triggered from the context menu fails because one or more in-scope source files could not be extracted, the system SHALL dismiss the progress modal and show a snackbar whose message states how many files failed, that no summary was saved, that re-running retries only the failed files, and what the underlying error was. When the analysis instead fails because no facts could be extracted at all, the snackbar SHALL name the analyzed word and state that no summary was saved. Both messages SHALL be localized for every supported display language (ja / en / zh).

Any other failure — one not carrying a per-file extraction outcome, such as a storage error raised before or around the extraction loop — SHALL continue to use the existing generic failure message.

The failed-file count SHALL NOT be persisted; it is conveyed to the user only through this notification.

#### Scenario: Partial extraction failure reports the count and the cause

- **WHEN** an analysis of "アリス" over five in-scope files fails because two of them could not be extracted, the first with a connection error
- **THEN** the progress modal SHALL be dismissed and a snackbar SHALL be shown whose message conveys that two files failed, that no summary was saved, and what the connection error was

#### Scenario: A run that extracted no facts names the word

- **WHEN** an analysis of "ボブ" fails because no in-scope file yielded any facts
- **THEN** a snackbar SHALL be shown naming "ボブ" and stating that no summary was saved, and the generic failure wording SHALL NOT be used

#### Scenario: A successful analysis keeps the existing message

- **WHEN** an analysis completes with every in-scope file extracted
- **THEN** the existing success snackbar naming the analyzed word SHALL be shown, unchanged

#### Scenario: An unclassified failure keeps the generic message

- **WHEN** an analysis fails with an error that carries no per-file extraction outcome (e.g. the novel's database is locked)
- **THEN** the existing generic failure snackbar SHALL be shown, without a failed-file count

#### Scenario: The failure message is localized

- **WHEN** the display language is `en` or `zh` and an analysis fails with a failed-file count
- **THEN** the snackbar message SHALL be rendered from that language's localization, not from the Japanese string
