## MODIFIED Requirements

### Requirement: Failure reports carry diagnostics alongside the headline

The system SHALL provide a single value type, `FailureReport`, that carries everything a failure notification needs: a localized `headline`, an optional raw `cause` string, an optional `stackTrace`, and a `diagnostics` map of ordered key/value pairs. Every user-facing failure surface routed through the shared notification path SHALL construct one.

The `diagnostics` map SHALL preserve insertion order so the rendered and copied output reads in the order the producer chose. Diagnostic keys SHALL be fixed English identifiers and SHALL NOT be localized, because they are read by whoever receives a bug report rather than by the reader operating the app.

Producers SHALL supply the application version as a diagnostic. The shared notification path SHALL NOT read it from a provider itself, so that the widgets stay testable without a Riverpod container.

The application version diagnostic SHALL identify the build the report came from, not only the release it belongs to. The declared version is held steady between releases, so every build made between two releases reports the same string; a report naming such a string cannot be matched to the code that produced it, and a question as ordinary as whether a given fix was present cannot be answered from the report. The diagnostic SHALL therefore also carry an identifier of the source the build was made from.

Where a build was produced without such an identifier, the diagnostic SHALL say that the identifier is absent rather than omit it or substitute a plausible value, so that a report from an unidentified build is recognisable as one. Builds produced by the project's release path SHALL carry the identifier.

#### Scenario: A report preserves diagnostic ordering

- **WHEN** a `FailureReport` is built with diagnostics inserted in the order `time`, `app version`, `provider`, `model`
- **THEN** iterating the diagnostics yields those keys in that same order

#### Scenario: A report without a cause or stack trace is valid

- **WHEN** a `FailureReport` is built with only a headline and diagnostics
- **THEN** the report is constructed successfully and its `cause` and `stackTrace` are null

#### Scenario: Two builds of one release are distinguishable

- **WHEN** two builds are made from different sources while the declared version is unchanged, and each produces a failure report
- **THEN** the application version diagnostics of the two reports SHALL differ

#### Scenario: A build with no identifier is recognisable

- **WHEN** a build is produced without a source identifier and a failure report is made from it
- **THEN** the application version diagnostic SHALL state that the identifier is absent, and SHALL NOT be indistinguishable from a report carrying one

#### Scenario: A release build carries the identifier

- **WHEN** a build is produced through the project's release path
- **THEN** its failure reports SHALL carry a source identifier in the application version diagnostic
