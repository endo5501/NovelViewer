## ADDED Requirements

### Requirement: Vertical text selection by drag
The system SHALL allow the user to select text in vertical display mode by click-and-drag gesture. The selection SHALL follow the vertical reading direction (top-to-bottom within a column, right-to-left across columns). The selection range SHALL be determined by mapping the pointer position to character indices using actual rendered widget rectangles collected via `GlobalKey` and `RenderBox`. During drag updates, the system SHALL snap to the nearest character region when the pointer is between characters.

#### Scenario: User selects text by dragging in vertical mode
- **WHEN** the user clicks and drags over characters in vertical display mode
- **THEN** the characters within the drag range are visually highlighted with a selection color

#### Scenario: Selection follows vertical reading order
- **WHEN** the user drags from a character in the right column to a character in the left column
- **THEN** all characters between the start and end positions are selected following top-to-bottom, right-to-left order

#### Scenario: Selection within a single column
- **WHEN** the user drags vertically within a single column
- **THEN** only the characters between the start and end positions within that column are selected

#### Scenario: Tap clears existing selection
- **WHEN** the user taps without dragging while a selection exists
- **THEN** the selection is cleared

### Requirement: Selected text extraction in vertical mode
The system SHALL extract the original (unmapped) text from the selected range and store it in the application state via `selectedTextProvider`. For ruby-annotated text, the base text (e.g., kanji) SHALL be used as the selected text content.

#### Scenario: Selected text is stored in application state
- **WHEN** the user completes a text selection in vertical mode
- **THEN** the selected text is stored in `selectedTextProvider` and accessible to other features (e.g., search)

#### Scenario: Ruby text selection extracts base text
- **WHEN** the user selects a range that includes ruby-annotated text
- **THEN** the extracted text contains the base text (e.g., kanji), not the ruby annotation

#### Scenario: Mapped characters are extracted as originals
- **WHEN** the user selects text that includes vertically mapped characters (e.g., `︒` displayed for `。`)
- **THEN** the extracted text contains the original characters (e.g., `。`), not the display-mapped characters

#### Scenario: Selection cleared updates provider
- **WHEN** the selection is cleared (by tap or page change)
- **THEN** `selectedTextProvider` is set to null

### Requirement: Selection visual feedback in vertical mode
The system SHALL display selected characters with a visually distinct background color that differs from the search highlight color. The selection highlight SHALL use a semi-transparent blue background (`Colors.blue` with opacity 0.3). Search highlights (yellow) SHALL take precedence when both selection and search highlight apply to the same character.

#### Scenario: Selected characters are highlighted with blue background
- **WHEN** characters are within the selection range
- **THEN** they are displayed with a semi-transparent blue background color

#### Scenario: Search highlight takes precedence over selection
- **WHEN** a character is both within the selection range and matches the active search query
- **THEN** the character is displayed with the search highlight color (yellow), not the selection color

#### Scenario: Non-selected characters have no selection highlight
- **WHEN** characters are outside the selection range
- **THEN** they are displayed with their normal background (or search highlight if applicable)

### Requirement: Selection state cleared on page navigation
The system SHALL clear the text selection when the user navigates to a different page in vertical display mode.

#### Scenario: Page forward clears selection
- **WHEN** the user presses the left arrow key to advance to the next page while text is selected
- **THEN** the selection is cleared and `selectedTextProvider` is set to null

#### Scenario: Page backward clears selection
- **WHEN** the user presses the right arrow key to go to the previous page while text is selected
- **THEN** the selection is cleared and `selectedTextProvider` is set to null
