## Purpose

Provide a cooperative cancellation mechanism for the novel download pipeline so a user can stop an in-progress download. Already-downloaded content is preserved (resumable), in-flight HTTP requests are aborted, and a user-initiated cancellation is surfaced distinctly from a failure/error in both state and UI.

## Requirements

### Requirement: Cancellation token

The system SHALL provide a lightweight, general-purpose cancellation mechanism (`CancellationToken`) usable by the download pipeline. A token SHALL expose whether it has been cancelled, a method to request cancellation, and a method to throw a `CancelledException` when cancellation has been requested. This mechanism is independent of the TTS FFI abort mechanism.

#### Scenario: Token starts uncancelled

- **WHEN** a `CancellationToken` is created
- **THEN** its cancelled state SHALL be `false` and `throwIfCancelled()` SHALL NOT throw

#### Scenario: Token reports cancellation

- **WHEN** `cancel()` is called on a token
- **THEN** its cancelled state SHALL become `true` and `throwIfCancelled()` SHALL throw a `CancelledException`

### Requirement: Cooperative download cancellation

`DownloadService.downloadNovel` SHALL accept an optional `CancellationToken`. When a token is provided, the system SHALL check for cancellation cooperatively before fetching each index page and at the start of each episode iteration, and SHALL abort an in-flight HTTP request by closing the owned `http.Client` when cancellation is requested. Episodes (and index pages) that were already saved/cached before cancellation SHALL remain on disk and in the cache so the download can be resumed from where it stopped on a later run.

#### Scenario: Cancellation stops further downloads

- **WHEN** a download is in progress and the cancellation token is cancelled mid-way through the episode loop
- **THEN** the system SHALL stop downloading remaining episodes and SHALL NOT process any further iterations

#### Scenario: Already-downloaded content is preserved

- **WHEN** a download is cancelled after N episodes have been saved and cached
- **THEN** those N episodes' `.txt` files SHALL remain on disk and their cache entries SHALL remain, and a later re-run SHALL skip them (cache hit) and continue with the rest

#### Scenario: In-flight request is aborted

- **WHEN** cancellation is requested while an HTTP request is in flight
- **THEN** the system SHALL close the owned `http.Client`, causing the in-flight request to fail rather than continuing to wait

#### Scenario: No token behaves as before

- **WHEN** `downloadNovel` is called without a cancellation token
- **THEN** the download SHALL behave exactly as before (no cancellation checks change observable behavior)

### Requirement: Cancellation UI and state

The download dialog SHALL present a cancel action while a download is in progress (replacing the disabled "downloading" button). Activating it SHALL request cancellation on the active token. The download state SHALL represent a user-initiated cancellation distinctly from a failure/error, and the dialog SHALL display a localized "cancelled" message rather than a red error message. The cancel-related user-visible strings SHALL be provided via `.arb` with full en/ja/zh parity.

#### Scenario: Cancel button is shown during download

- **WHEN** a download is in progress
- **THEN** the dialog SHALL display an enabled cancel button

#### Scenario: Cancel button requests cancellation

- **WHEN** the user activates the cancel button during a download
- **THEN** the notifier SHALL request cancellation on the active token

#### Scenario: Cancelled state is distinct from error

- **WHEN** a download ends because the user cancelled it
- **THEN** the download state SHALL be a dedicated cancelled state (not the error state), and the dialog SHALL show a localized cancellation message rather than a red error message

#### Scenario: Cancel strings have full locale parity

- **WHEN** the application is built for en, ja, or zh
- **THEN** the cancel button label and cancelled message SHALL be present in all three `.arb` files with no missing-translation warnings
