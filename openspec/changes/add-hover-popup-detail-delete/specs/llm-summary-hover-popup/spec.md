## ADDED Requirements

### Requirement: Detail and delete controls on the popup
The popup SHALL include two controls, a "詳細を表示" control and a "削除" control, on a row of their own below the summary text, aligned to the trailing edge. Each SHALL show an icon together with its localized label. They live in the popup because the moment a reader judges a summary unsatisfactory, or wants to see what it was built from, is while reading it there. They take a row of their own rather than joining the re-analysis control in the header: the header's width is shared with the snapshot label, and on a touch device the label would otherwise have to be cut short to make room.

Both controls SHALL be present whether or not LLM summary is available on the running platform. Neither needs the LLM: one reads stored data and the other removes it. Where analysis is unavailable, the popup is the only place a stored analysis can be removed, since the analysis history tab is absent there.

Activating "詳細を表示" SHALL open the word detail dialog defined by `llm-summary-history-detail-view` for the popup's word, reading the novel folder the popup was opened over.

Activating "削除" SHALL first show a confirmation dialog naming the word and stating that its analysis results (summaries and facts) will be deleted. The dialog SHALL offer a cancel action and a delete action. The delete action SHALL be visually marked as destructive. A control inside a transient popup over the text is easier to press by mistake than a context-menu item, and the deletion cannot be undone. The confirmation is specific to this entry point: the analysis history context menu's "削除" keeps its existing, unconfirmed behavior.

Confirming SHALL delete the word's analysis exactly as the analysis history context menu's "削除" does. Every snapshot row for the word SHALL be removed from `word_summaries`, and its rows SHALL be removed from `fact_cache`. The deletion SHALL act on the novel folder the popup was opened over. Per-snapshot deletion SHALL NOT be offered. Afterwards the word's marks SHALL disappear from the text and the analysis history list SHALL no longer show the word.

Cancelling SHALL leave `word_summaries` and `fact_cache` unchanged.

Activating either control SHALL dismiss the popup before its dialog opens, and the popup SHALL NOT reappear when the dialog closes. Left up, the popup could sit over the dialog and take the touches meant for the dialog's buttons. The dialog and the confirmed deletion SHALL still take effect after the popup that started them has gone.

#### Scenario: Both controls are shown below the summary
- **WHEN** the popup opens for a word with a stored snapshot on a platform where LLM summary is available
- **THEN** the "詳細を表示" and "削除" controls SHALL be displayed with their labels below the summary text
- **AND** the re-analysis control SHALL remain in the header

#### Scenario: Both controls are shown where analysis is unavailable
- **WHEN** the popup opens for a word with a stored snapshot on a platform where LLM summary is unavailable
- **THEN** the "詳細を表示" and "削除" controls SHALL be displayed
- **AND** no re-analysis control SHALL be present

#### Scenario: The detail control opens the word detail dialog
- **WHEN** the user activates "詳細を表示" in the popup for the word "アリス"
- **THEN** the word detail dialog for "アリス" SHALL open with its "事実" tab selected

#### Scenario: The delete control asks for confirmation first
- **WHEN** the user activates "削除" in the popup for the word "アリス"
- **THEN** a confirmation dialog naming "アリス" SHALL appear
- **AND** no row SHALL have been deleted yet

#### Scenario: Confirming deletes every snapshot and the facts for the word
- **WHEN** the user confirms the deletion of "アリス", which has three snapshots and cached facts in the active novel
- **THEN** all three `word_summaries` rows for "アリス" SHALL be deleted
- **AND** all `fact_cache` rows for "アリス" SHALL be deleted
- **AND** "アリス" SHALL no longer be marked in the text or listed in the analysis history

#### Scenario: Cancelling leaves the analysis intact
- **WHEN** the user cancels the confirmation dialog for "アリス"
- **THEN** no `word_summaries` or `fact_cache` row for "アリス" SHALL be deleted
- **AND** "アリス" SHALL remain marked in the text

#### Scenario: Deletion acts on the novel the popup was opened over
- **WHEN** the popup was opened over novel A and the user confirms deletion
- **THEN** the rows SHALL be deleted from novel A's data only

#### Scenario: The popup is gone before either dialog opens
- **WHEN** the user activates "詳細を表示" or "削除" in the popup, by mouse or by touch
- **THEN** the popup SHALL be dismissed
- **AND** the dialog SHALL open with nothing from the popup drawn over it

#### Scenario: A touch on either control does not dismiss the popup before it acts
- **WHEN** the reader touches the "削除" control with a finger
- **THEN** the confirmation dialog SHALL appear
- **AND** the touch SHALL NOT be treated as a touch outside the popup
