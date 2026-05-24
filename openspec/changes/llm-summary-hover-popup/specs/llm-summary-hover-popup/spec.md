## ADDED Requirements

### Requirement: Hover popup on marked words in horizontal mode
In horizontal display mode, the text viewer SHALL display a popup widget over the text when the mouse pointer enters the screen region of any marked word (a word with a dotted or solid mark from `llm-summary`'s mark rendering). The popup SHALL be displayed only while the pointer remains within the marked word's character range and SHALL disappear immediately when the pointer leaves that range. The popup SHALL NOT trigger for unmarked text.

#### Scenario: Hover over a marked word shows popup
- **WHEN** the user moves the mouse pointer onto an occurrence of the word "アリス" which has a cached summary for the active folder, in horizontal display mode
- **THEN** a popup widget SHALL appear near the pointer position displaying the cached summary text for "アリス"

#### Scenario: Pointer leaves marked word hides popup
- **WHEN** the popup is being displayed and the user moves the mouse pointer outside the character range of the marked word
- **THEN** the popup SHALL disappear immediately

#### Scenario: Hover over unmarked text does not show popup
- **WHEN** the user moves the mouse pointer over text that is not marked (no cached summary)
- **THEN** no popup SHALL appear

### Requirement: Hover popup disabled in vertical mode
In vertical display mode, the hover popup SHALL NOT be displayed regardless of whether the pointer is over a marked word. The mark rendering (sidebar lines) SHALL remain functional.

#### Scenario: Hover over marked word in vertical mode does not show popup
- **WHEN** the user moves the mouse pointer onto a marked word in vertical display mode
- **THEN** no popup SHALL appear
- **AND** the sidebar line mark SHALL remain rendered as defined by `llm-summary`

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

### Requirement: Popup content is non-interactive (no copy)
The popup body SHALL render the summary text as non-selectable plain text. The popup SHALL NOT capture pointer events that would prevent the underlying hover detection from firing the exit handler when the pointer leaves the marked word range.

#### Scenario: Popup text is not selectable
- **WHEN** the popup is displayed and the user attempts to drag-select text within it
- **THEN** no text selection SHALL occur in the popup

#### Scenario: Pointer moving from marked word toward popup still hides popup when leaving the word range
- **WHEN** the popup is displayed and the user moves the pointer off the marked word into any other area (including the area occupied by the popup itself)
- **THEN** the popup SHALL disappear

### Requirement: Popup display while cache is loading
When the popup is triggered, the system SHALL fetch the cached summary asynchronously from the `word_summaries` table. While the fetch is in flight, the popup SHALL display a small loading indicator. If the fetch resolves to a value, the popup SHALL display the resolved content. If the pointer leaves the marked word range before the fetch resolves, the popup SHALL be hidden and the resolved data SHALL be discarded.

#### Scenario: Loading indicator while cache fetch in flight
- **WHEN** the user hovers over a marked word and the cache fetch has not yet completed
- **THEN** the popup SHALL display a small loading indicator

#### Scenario: Content replaces loading indicator on resolve
- **WHEN** the cache fetch resolves with summary data while the pointer is still within the marked word range
- **THEN** the popup SHALL replace the loading indicator with the resolved summary content
