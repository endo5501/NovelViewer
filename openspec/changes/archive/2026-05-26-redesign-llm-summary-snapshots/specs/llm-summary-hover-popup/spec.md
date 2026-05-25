## ADDED Requirements

### Requirement: Snapshot selector and "X話時点" label
When a marked word has at least one cached snapshot, the popup SHALL display the selected snapshot's summary together with a label of the form "Xファイル時点の要約" (where X is the snapshot's `covered_up_to_episode`). When more than one snapshot exists, the popup SHALL also render a navigation control (◀ / ▶) that lets the user step through snapshots in ascending order of `covered_up_to_episode`. The initial selection SHALL follow the default rule defined in `llm-summary-cache` ("max{Sᵢ | Sᵢ ≤ C}" with fall-back to `min{Sᵢ}` when no past snapshot exists). When only one snapshot exists, the navigation arrows SHALL still be rendered for layout stability but SHALL be disabled (visibly dimmed, tap inert).

#### Scenario: Default selection shows latest past snapshot
- **WHEN** the popup opens for "アリス" with snapshots at `{3, 9, 10, 20}` while the current file's prefix is `6`
- **THEN** the popup SHALL initially display the snapshot for `covered_up_to_episode=3` (= `max{Sᵢ | Sᵢ ≤ 6}`)
- **AND** the popup label SHALL read "3ファイル時点の要約" (or its locale equivalent)

#### Scenario: Step forward to the next snapshot
- **WHEN** the popup is displaying the snapshot at `covered_up_to_episode=3` and snapshots `{3, 9, 10, 20}` exist
- **THEN** clicking the ▶ control SHALL advance the display to the snapshot at `covered_up_to_episode=9`
- **AND** the label SHALL update to "9ファイル時点の要約"

#### Scenario: Step backward to the previous snapshot
- **WHEN** the popup is displaying the snapshot at `covered_up_to_episode=9` and snapshots `{3, 9, 10, 20}` exist
- **THEN** clicking the ◀ control SHALL move the display back to the snapshot at `covered_up_to_episode=3`

#### Scenario: Navigation arrows disabled when only one snapshot exists
- **WHEN** the popup is displaying the only existing snapshot for the word
- **THEN** both ◀ and ▶ controls SHALL be rendered but SHALL be visually dimmed and SHALL not respond to taps

#### Scenario: Forward control disabled at the highest snapshot
- **WHEN** the popup is displaying the highest-`covered_up_to_episode` snapshot
- **THEN** the ▶ control SHALL be disabled and only ◀ SHALL be active

### Requirement: Future-snapshot warning icon
When the currently selected snapshot's `covered_up_to_episode` is strictly greater than the numeric prefix `C` of the currently viewed file, the popup SHALL render a small warning icon (Material `warning_amber_outlined` in an orange shade) next to the "Xファイル時点の要約" label, signaling that the snapshot may reveal information from files the user has not yet read. No warning SHALL be shown when `covered_up_to_episode <= C`. The popup body itself SHALL be displayed immediately without any blur, opacity reduction, or click-to-reveal gate.

#### Scenario: Warning shown when displaying a future snapshot
- **WHEN** the popup is displaying the snapshot at `covered_up_to_episode=9` while the current file's prefix is `6`
- **THEN** the warning icon SHALL be visible next to the snapshot label
- **AND** the summary text SHALL be visible immediately without any visual obstruction

#### Scenario: No warning when displaying a past or current snapshot
- **WHEN** the popup is displaying the snapshot at `covered_up_to_episode=3` while the current file's prefix is `6`
- **THEN** no warning icon SHALL be displayed

#### Scenario: No warning when snapshot equals current
- **WHEN** the popup is displaying a snapshot whose `covered_up_to_episode` equals the current file's prefix
- **THEN** no warning icon SHALL be displayed

### Requirement: Re-analysis dropdown on the popup
The popup SHALL include a re-analysis control (e.g., a button labeled "再解析" with a dropdown indicator) in the top-right area of the popup. Activating the control SHALL open a dropdown menu containing two items:

1. "現在ページまで (Nファイル時点)" — where N is the numeric prefix of the currently viewed file (or its lexical rank when no numeric prefix exists). Selecting this item SHALL invoke the LLM analysis pipeline with `covered_up_to_episode=N` (equivalent to the "解析開始(ネタバレなし)" trigger).
2. "全話まで (Mファイル時点)" — where M is the highest numeric prefix in the folder. Selecting this item SHALL invoke the pipeline with `covered_up_to_episode=M` (equivalent to "解析開始(ネタバレあり)").

Each item SHALL append the localized suffix " (上書き)" when an existing snapshot row already matches the would-be `covered_up_to_episode`. Selecting an item that would overwrite SHALL proceed without a confirmation dialog (mirroring the existing context-menu re-analysis behavior). The popup itself SHALL remain visible while the re-analysis dropdown is open; the existing pointer grace period and `MouseRegion` handling SHALL be extended to cover the dropdown menu so that opening it does not cause the popup to dismiss.

#### Scenario: Both items present with episode hints
- **WHEN** the popup is open while viewing "040_chapter.txt" in a folder whose highest-prefix file is "120_chapter.txt", and no snapshot currently exists at episodes 40 or 120
- **THEN** the re-analysis dropdown SHALL list "現在ページまで (40ファイル時点)" and "全話まで (120ファイル時点)" with no "(上書き)" suffix on either item

#### Scenario: Overwrite suffix when current-page snapshot already exists
- **WHEN** the popup is open while viewing "040_chapter.txt" and a snapshot at `covered_up_to_episode=40` already exists for the word
- **THEN** the dropdown item "現在ページまで (40ファイル時点)" SHALL be displayed with the "(上書き)" suffix

#### Scenario: Overwrite suffix when full-scope snapshot already exists
- **WHEN** the folder's highest-prefix file is "120_chapter.txt" and a snapshot at `covered_up_to_episode=120` already exists for the word
- **THEN** the dropdown item "全話まで (120ファイル時点)" SHALL be displayed with the "(上書き)" suffix

#### Scenario: Selecting an item triggers analysis without confirmation
- **WHEN** the user selects "現在ページまで (40ファイル時点) (上書き)"
- **THEN** the existing snapshot at `covered_up_to_episode=40` SHALL be overwritten by the new analysis result; no confirmation dialog SHALL be shown
- **AND** the standard analysis modal (with spinner and pipeline progress label) SHALL appear during the call

#### Scenario: Popup stays visible while the dropdown is open
- **WHEN** the user opens the re-analysis dropdown and the pointer is anywhere within the dropdown menu region
- **THEN** the popup SHALL NOT dismiss due to the pointer leaving the marked word range

#### Scenario: Closing the dropdown without selection returns to popup
- **WHEN** the user dismisses the dropdown without picking an item
- **THEN** the popup SHALL remain visible in its prior state (same selected snapshot)

## MODIFIED Requirements

### Requirement: Hover popup on marked words in horizontal mode
In horizontal display mode, the text viewer SHALL display a popup widget over the text when the mouse pointer enters the screen region of any marked word (a word with a solid mark from `llm-summary`'s uniform mark rendering). The popup SHALL be displayed while the pointer remains within either the marked word's character range OR the popup widget itself (including any of its child overlays such as the re-analysis dropdown); when the pointer leaves the marked word, a short grace period (~150 ms) SHALL allow the pointer to travel into the popup to interact with controls such as the snapshot navigator (◀/▶) or the re-analysis dropdown. The popup SHALL NOT trigger for unmarked text.

#### Scenario: Hover over a marked word shows popup
- **WHEN** the user moves the mouse pointer onto an occurrence of the word "アリス" which has at least one cached snapshot for the active folder, in horizontal display mode
- **THEN** a popup widget SHALL appear near the pointer position displaying the default-selected snapshot's summary text

#### Scenario: Pointer leaves marked word without reaching popup hides it
- **WHEN** the popup is displayed, the user moves the pointer off the marked word, and the pointer does NOT enter the popup widget within the grace period
- **THEN** the popup SHALL disappear after the grace period elapses

#### Scenario: Pointer enters popup before grace period elapses keeps it visible
- **WHEN** the popup is displayed and the user moves the pointer from the marked word into the popup widget within the grace period
- **THEN** the popup SHALL remain visible for as long as the pointer stays inside the popup
- **AND** the user SHALL be able to click controls inside the popup such as the snapshot navigator and the re-analysis dropdown

#### Scenario: Pointer leaves popup hides it immediately
- **WHEN** the popup is displayed, the pointer is currently inside the popup widget (with no child overlay open), and the pointer leaves the popup
- **THEN** the popup SHALL disappear immediately without waiting for the grace period

#### Scenario: Hover over unmarked text does not show popup
- **WHEN** the user moves the mouse pointer over text that is not marked (no cached snapshot)
- **THEN** no popup SHALL appear

### Requirement: Hover popup on marked characters in vertical mode
In vertical display mode, the text viewer SHALL display the hover popup over the text when the mouse pointer enters the screen region of any marked character (a character that falls inside a mark range derived from the active `markedWords` set, rendered with a sidebar line by `llm-summary`). The popup SHALL remain visible while the pointer continues to hover within the same mark range OR enters the popup widget itself (including any of its child overlays); when the pointer transitions outside the mark range, into a different mark range, or leaves the text region entirely, the same grace period (~150 ms) defined for horizontal mode SHALL apply. The popup body, the snapshot label, the snapshot navigator, the warning icon, the re-analysis dropdown, the loading indicator, and non-selectable text behavior SHALL be identical to horizontal mode.

#### Scenario: Hover over a marked character shows popup in vertical mode
- **WHEN** the display mode is vertical, the user moves the mouse pointer onto a character whose enclosing mark range corresponds to the word "アリス" which has at least one cached snapshot for the active folder
- **THEN** a popup widget SHALL appear near the pointer position displaying the default-selected snapshot's summary text
- **AND** the sidebar line mark on the character SHALL remain rendered

#### Scenario: Pointer moves within the same mark range keeps popup stable
- **WHEN** the popup is visible for word "アリス" in vertical mode and the user moves the pointer to another character that belongs to the same mark range for "アリス"
- **THEN** the popup SHALL remain visible without flicker or re-creation

#### Scenario: Pointer transitions to a different marked word switches popup
- **WHEN** the popup is visible for word "アリス" in vertical mode and the user moves the pointer onto a character belonging to a different mark range for the word "ボブ" which also has at least one cached snapshot
- **THEN** the popup SHALL update to display the default-selected snapshot for "ボブ"

#### Scenario: Pointer leaves marked character in vertical mode hides popup after grace period
- **WHEN** the popup is visible in vertical mode, the user moves the pointer off any marked character into unmarked text or empty area, and the pointer does NOT enter the popup widget within the grace period
- **THEN** the popup SHALL disappear after the grace period elapses

#### Scenario: Pointer enters popup before grace period elapses keeps it visible (vertical mode)
- **WHEN** the popup is visible in vertical mode and the user moves the pointer from a marked character into the popup widget within the grace period
- **THEN** the popup SHALL remain visible for as long as the pointer stays inside the popup
- **AND** the user SHALL be able to click controls inside the popup such as the snapshot navigator and the re-analysis dropdown

#### Scenario: Hover over unmarked text in vertical mode does not show popup
- **WHEN** the display mode is vertical and the user moves the pointer over text that is not within any mark range
- **THEN** no popup SHALL appear

#### Scenario: Drag selection in vertical mode hides popup
- **WHEN** the popup is visible in vertical mode and the user presses the primary mouse button to begin a drag selection
- **THEN** the popup SHALL be hidden before selection updates begin

#### Scenario: Page transition in vertical mode hides popup
- **WHEN** the popup is visible in vertical mode and the user triggers a page change (swipe, arrow key, or scroll wheel)
- **THEN** the popup SHALL be hidden as the page transition starts

## REMOVED Requirements

### Requirement: Default summary type and switching pill
**Reason**: Replaced by "Snapshot selector and 'X話時点' label". The `[なし|あり]` pill assumed the deprecated `summary_type` taxonomy; the new model uses snapshot navigation (◀/▶) instead.
**Migration**: Implementations SHALL remove the `_TypeToggle` widget and the popup state's `activeType: SummaryType` field, replacing them with the snapshot selector widget and an `activeEpisode: int?` field that defaults to the snapshot-selection rule.

### Requirement: Reference-position warning in popup
**Reason**: The "別ファイルで解析した要約です" warning is replaced by the more informative "Xファイル時点の要約" label (always present) and the future-snapshot warning icon (shown only when `covered_up_to_episode > C`).
**Migration**: Implementations SHALL remove `_ReferenceWarning` and replace it with the snapshot label + warning icon combination defined in this delta.
