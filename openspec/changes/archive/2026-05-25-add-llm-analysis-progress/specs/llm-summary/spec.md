## ADDED Requirements

### Requirement: Analysis modal displays pipeline progress

The analysis modal shown during LLM word/phrase analysis SHALL subscribe to the pipeline's progress notifications and display a phase-appropriate label with current/total counters. The modal SHALL continue to show a spinner alongside the label so the user has both a visual cue that work is ongoing and a textual cue of what is happening.

The label content SHALL be:

- Before any progress event arrives (e.g., during the initial context search), the existing "LLM 解析中…" / locale-equivalent label.
- During the initial fact-extraction round (`round = 1`), a localized "情報を抽出中" label with `current / total` counters.
- During subsequent refinement rounds (`round >= 2`), a localized "絞り込み N 周目" label (where N is the `round` value) with `current / total` counters.
- During the final summary phase, a localized "最終要約を生成中…" label without counters.

The modal SHALL update reactively each time a new progress event arrives, without dismissing and re-opening the dialog. Modal dismissal SHALL continue to be driven by completion or error of the analysis, not by progress events.

#### Scenario: Initial label before any progress event

- **WHEN** the user triggers an analysis and the modal opens, but no progress event has been emitted yet (still in context search)
- **THEN** the modal displays the localized "LLM 解析中…" label

#### Scenario: Fact extraction shows current/total

- **WHEN** the pipeline emits a fact-extraction event with `round = 1`, `current = 2`, `total = 5`
- **THEN** the modal displays a label matching "情報を抽出中 (2 / 5)" in the active locale

#### Scenario: Refinement shows round number

- **WHEN** the pipeline emits a fact-extraction event with `round = 3`, `current = 1`, `total = 2`
- **THEN** the modal displays a label matching "絞り込み 3 周目 (1 / 2)" in the active locale

#### Scenario: Final summary shows summary label

- **WHEN** the pipeline emits the `AnalysisGeneratingFinalSummary` event
- **THEN** the modal displays the localized "最終要約を生成中…" label and stops showing the chunk counters

#### Scenario: Modal stays open across progress events

- **WHEN** multiple progress events are emitted in succession during a single analysis
- **THEN** the same modal route remains active, only its inner content changes; the dialog is not re-pushed onto the navigator

#### Scenario: Modal closes only on completion or error

- **WHEN** the pipeline finishes successfully or throws an exception
- **THEN** the modal route is removed from the navigator exactly as it is in the prior behavior, regardless of which progress event was last seen
