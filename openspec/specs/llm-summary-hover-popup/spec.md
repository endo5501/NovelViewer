# llm-summary-hover-popup Specification

## Purpose
TBD - created by archiving change llm-summary-hover-popup. Update Purpose after archive.
## Requirements
### Requirement: Hover popup on marked words in horizontal mode
In horizontal display mode, the text viewer SHALL display a popup widget over the text when the mouse pointer enters the screen region of any marked word (a word with a dotted or solid mark from `llm-summary`'s mark rendering). The popup SHALL be displayed while the pointer remains within either the marked word's character range OR the popup widget itself; when the pointer leaves the marked word, a short grace period (~150 ms) SHALL allow the pointer to travel into the popup to interact with controls such as the no-spoiler / spoiler toggle. The popup SHALL NOT trigger for unmarked text.

#### Scenario: Hover over a marked word shows popup
- **WHEN** the user moves the mouse pointer onto an occurrence of the word "アリス" which has a cached summary for the active folder, in horizontal display mode
- **THEN** a popup widget SHALL appear near the pointer position displaying the cached summary text for "アリス"

#### Scenario: Pointer leaves marked word without reaching popup hides it
- **WHEN** the popup is displayed, the user moves the pointer off the marked word, and the pointer does NOT enter the popup widget within the grace period
- **THEN** the popup SHALL disappear after the grace period elapses

#### Scenario: Pointer enters popup before grace period elapses keeps it visible
- **WHEN** the popup is displayed and the user moves the pointer from the marked word into the popup widget within the grace period
- **THEN** the popup SHALL remain visible for as long as the pointer stays inside the popup
- **AND** the user SHALL be able to click controls inside the popup such as the no-spoiler / spoiler toggle pill

#### Scenario: Pointer leaves popup hides it immediately
- **WHEN** the popup is displayed, the pointer is currently inside the popup widget, and the pointer leaves the popup
- **THEN** the popup SHALL disappear immediately without waiting for the grace period

#### Scenario: Hover over unmarked text does not show popup
- **WHEN** the user moves the mouse pointer over text that is not marked (no cached summary)
- **THEN** no popup SHALL appear

### Requirement: Hover popup on marked characters in vertical mode
In vertical display mode, the text viewer SHALL display the hover popup over the text when the mouse pointer enters the screen region of any marked character (a character that falls inside a mark range derived from the active `markedWords` set, rendered with a sidebar line by `llm-summary`). The popup SHALL remain visible while the pointer continues to hover within the same mark range OR enters the popup widget itself; when the pointer transitions outside the mark range, into a different mark range, or leaves the text region entirely, the same grace period (~150 ms) defined for horizontal mode SHALL apply, allowing the pointer to travel into the popup to interact with controls such as the no-spoiler / spoiler toggle. The popup body, [なし|あり] toggle pill, reference-position warning, loading indicator, and non-selectable text behavior SHALL be identical to horizontal mode.

#### Scenario: Hover over a marked character shows popup in vertical mode
- **WHEN** the display mode is vertical, the user moves the mouse pointer onto a character whose enclosing mark range corresponds to the word "アリス" which has a cached summary for the active folder
- **THEN** a popup widget SHALL appear near the pointer position displaying the cached summary text for "アリス"
- **AND** the sidebar line mark on the character SHALL remain rendered

#### Scenario: Pointer moves within the same mark range keeps popup stable
- **WHEN** the popup is visible for word "アリス" in vertical mode and the user moves the pointer to another character that belongs to the same mark range for "アリス"
- **THEN** the popup SHALL remain visible without flicker or re-creation

#### Scenario: Pointer transitions to a different marked word switches popup
- **WHEN** the popup is visible for word "アリス" in vertical mode and the user moves the pointer onto a character belonging to a different mark range for the word "ボブ" which also has a cached summary
- **THEN** the popup SHALL update to display the cached summary for "ボブ"

#### Scenario: Pointer leaves marked character in vertical mode hides popup after grace period
- **WHEN** the popup is visible in vertical mode, the user moves the pointer off any marked character into unmarked text or empty area, and the pointer does NOT enter the popup widget within the grace period
- **THEN** the popup SHALL disappear after the grace period elapses

#### Scenario: Pointer enters popup before grace period elapses keeps it visible (vertical mode)
- **WHEN** the popup is visible in vertical mode and the user moves the pointer from a marked character into the popup widget within the grace period
- **THEN** the popup SHALL remain visible for as long as the pointer stays inside the popup
- **AND** the user SHALL be able to click controls inside the popup such as the no-spoiler / spoiler toggle pill

#### Scenario: Hover over unmarked text in vertical mode does not show popup
- **WHEN** the display mode is vertical and the user moves the pointer over text that is not within any mark range
- **THEN** no popup SHALL appear

#### Scenario: Drag selection in vertical mode hides popup
- **WHEN** the popup is visible in vertical mode and the user presses the primary mouse button to begin a drag selection
- **THEN** the popup SHALL be hidden before selection updates begin

#### Scenario: Page transition in vertical mode hides popup
- **WHEN** the popup is visible in vertical mode and the user triggers a page change (swipe, arrow key, or scroll wheel)
- **THEN** the popup SHALL be hidden as the page transition starts

### Requirement: Popup position adjusts for display mode
The hover popup SHALL be positioned relative to the pointer based on the active display mode so the popup does not obscure the natural reading flow. In horizontal mode the popup SHALL appear with its top-left corner offset 16 px right and 16 px below the pointer position. In vertical mode the popup SHALL appear with its bottom-left corner offset 16 px right and 16 px above the pointer position; if this placement would cause the popup to overflow the right edge of the screen, the horizontal anchor SHALL flip so the popup appears to the left of the pointer instead; if the placement would cause the popup to overflow the top edge of the screen, the vertical anchor SHALL flip so the popup appears below the pointer instead.

#### Scenario: Horizontal mode places popup down-right of pointer
- **WHEN** the popup is shown for a marked word in horizontal mode at pointer global position (P)
- **THEN** the popup's top-left corner SHALL be at approximately (P.dx + 16, P.dy + 16)

#### Scenario: Vertical mode places popup up-right of pointer when screen permits
- **WHEN** the popup is shown for a marked character in vertical mode at pointer global position (P) with enough room to the right and above
- **THEN** the popup's bottom-left corner SHALL be at approximately (P.dx + 16, P.dy − 16) so the popup floats above and to the right of the pointer

#### Scenario: Vertical mode flips horizontally near the right screen edge
- **WHEN** the popup is shown in vertical mode at pointer global position (P) and placing the popup to the right would extend beyond the screen's right edge
- **THEN** the popup's right edge SHALL be placed to the left of the pointer instead (popup appears up-left of the pointer)

#### Scenario: Vertical mode flips vertically near the top screen edge
- **WHEN** the popup is shown in vertical mode at pointer global position (P) and placing the popup above would extend beyond the screen's top edge
- **THEN** the popup SHALL be placed below the pointer instead (popup appears down-right, mirroring the horizontal-mode placement)

### Requirement: Popup hides on display mode switch
When the user changes the text display mode (horizontal ↔ vertical) while a popup is visible, the system SHALL hide the popup immediately. This prevents a popup whose position was computed for the previous mode's layout from lingering after the mode switch.

#### Scenario: Switching from horizontal to vertical hides an open popup
- **WHEN** the popup is visible in horizontal mode and the user switches the display mode to vertical
- **THEN** the popup SHALL be hidden before the new mode renders

#### Scenario: Switching from vertical to horizontal hides an open popup
- **WHEN** the popup is visible in vertical mode and the user switches the display mode to horizontal
- **THEN** the popup SHALL be hidden before the new mode renders

### Requirement: Default summary type and switching pill
When a marked word has both a no-spoiler and a spoiler cached summary, the popup SHALL display the no-spoiler summary by default and SHALL include a switching control (segmented pill labeled "なし" / "あり") that allows the user to switch to the spoiler summary while the popup is open. When the word has only one cached type, the popup SHALL display that type without the switching control.

#### Scenario: Default to no-spoiler when both types cached
- **WHEN** the user hovers over a word that has both a no-spoiler and a spoiler cached summary
- **THEN** the popup SHALL display the no-spoiler summary text
- **AND** the popup SHALL include a [なし|あり] segmented pill with "なし" selected

#### Scenario: Switch to spoiler via pill
- **WHEN** the popup is displaying a no-spoiler summary with the [なし|あり] pill, and the user clicks "あり"
- **THEN** the popup content SHALL update to display the spoiler summary text
- **AND** the pill SHALL show "あり" as selected

#### Scenario: Single-type cache hides pill
- **WHEN** the user hovers over a word that has only a no-spoiler cache (or only a spoiler cache)
- **THEN** the popup SHALL display that cached summary without the [なし|あり] pill

### Requirement: Reference-position warning in popup
When the popup is displaying a no-spoiler summary whose source `word_summaries.source_file` differs from the currently displayed file, the popup SHALL include a small warning text indicating that the summary was generated from a different file. When the source file matches or when displaying a spoiler summary, the warning SHALL NOT be displayed.

#### Scenario: Warn when no-spoiler source differs from current file
- **WHEN** the popup is displaying the no-spoiler summary for "アリス", the no-spoiler row's `source_file` is "030_chapter.txt", and the currently displayed file is "040_chapter.txt"
- **THEN** the popup SHALL display a small warning text near the bottom of the popup indicating the summary was generated from a different file

#### Scenario: No warning when source matches current file
- **WHEN** the popup is displaying the no-spoiler summary for "アリス" and its `source_file` matches the currently displayed file
- **THEN** the popup SHALL NOT display the reference-position warning

#### Scenario: No warning when displaying spoiler summary
- **WHEN** the popup is displaying the spoiler summary for "アリス" (regardless of `source_file` value)
- **THEN** the popup SHALL NOT display the reference-position warning

### Requirement: Popup body text is non-selectable
The popup body SHALL render the summary text as non-selectable plain text. (Users who want to copy summary text use the copy actions on the analysis history panel — see `llm-summary-history-ui`.)

#### Scenario: Popup text is not selectable
- **WHEN** the popup is displayed and the user attempts to drag-select text within it
- **THEN** no text selection SHALL occur in the popup

### Requirement: Popup display while cache is loading
When the popup is triggered, the system SHALL fetch the cached summary asynchronously from the `word_summaries` table. While the fetch is in flight, the popup SHALL display a small loading indicator. If the fetch resolves to a value, the popup SHALL display the resolved content. If the pointer leaves the marked word range (and does not enter the popup within the grace period) before the fetch resolves, the popup SHALL be hidden and the resolved data SHALL be discarded.

#### Scenario: Loading indicator while cache fetch in flight
- **WHEN** the user hovers over a marked word and the cache fetch has not yet completed
- **THEN** the popup SHALL display a small loading indicator

#### Scenario: Content replaces loading indicator on resolve
- **WHEN** the cache fetch resolves with summary data while the pointer is still within the marked word range
- **THEN** the popup SHALL replace the loading indicator with the resolved summary content

