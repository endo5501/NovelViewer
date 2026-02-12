## ADDED Requirements

### Requirement: Vertical text rendering
The system SHALL render text content in vertical writing mode (top-to-bottom, right-to-left columns) using a Wrap widget with vertical axis direction and RTL text direction. Each character SHALL be rendered individually as a separate widget within the Wrap layout.

#### Scenario: Text is displayed vertically
- **WHEN** the display mode is set to vertical
- **THEN** characters are arranged from top to bottom within each column, and columns flow from right to left

#### Scenario: Line breaks create new columns
- **WHEN** the text content contains newline characters in vertical mode
- **THEN** a new column starts at the position of each newline, with subsequent text continuing from the top of the new column

#### Scenario: Column overflow wraps to next column
- **WHEN** a column of text exceeds the available vertical height
- **THEN** the remaining characters wrap to a new column to the left

### Requirement: Vertical character mapping
The system SHALL replace horizontal-specific punctuation and brackets with their vertical writing equivalents when rendering in vertical mode.

#### Scenario: Period is mapped to vertical form
- **WHEN** the character "。" is encountered in vertical mode
- **THEN** it is rendered as "︒" (vertical ideographic full stop)

#### Scenario: Comma is mapped to vertical form
- **WHEN** the character "、" is encountered in vertical mode
- **THEN** it is rendered as "︑" (vertical ideographic comma)

#### Scenario: Opening bracket is mapped to vertical form
- **WHEN** the character "「" is encountered in vertical mode
- **THEN** it is rendered as "﹁" (vertical left corner bracket)

#### Scenario: Closing bracket is mapped to vertical form
- **WHEN** the character "」" is encountered in vertical mode
- **THEN** it is rendered as "﹂" (vertical right corner bracket)

#### Scenario: Parentheses are mapped to vertical form
- **WHEN** the characters "（" or "）" are encountered in vertical mode
- **THEN** they are rendered as "︵" or "︶" respectively (vertical parentheses)

#### Scenario: Ellipsis is mapped to vertical form
- **WHEN** the character "…" is encountered in vertical mode
- **THEN** it is rendered as "︙" (vertical ellipsis)

#### Scenario: Unmapped characters remain unchanged
- **WHEN** a character without a vertical mapping is encountered in vertical mode
- **THEN** the character is rendered as-is without transformation

### Requirement: Vertical text pagination
The system SHALL display vertical text in pages rather than as a scrollable area. Page boundaries SHALL be calculated dynamically based on the available display area dimensions and character/column sizing.

#### Scenario: Text is split into pages
- **WHEN** the text content exceeds the available display area in vertical mode
- **THEN** the text is divided into pages, each fitting within the display area

#### Scenario: Page boundary adjusts to window size
- **WHEN** the application window is resized while in vertical display mode
- **THEN** the page boundaries are recalculated to fit the new display area

#### Scenario: Current page indicator is displayed
- **WHEN** a paginated vertical text is displayed
- **THEN** the current page number and total page count are shown (e.g., "3 / 15")

### Requirement: Arrow key page navigation
The system SHALL support left and right arrow key presses to navigate between pages in vertical display mode. The left arrow key SHALL advance to the next page and the right arrow key SHALL go to the previous page, matching the right-to-left reading direction of vertical Japanese text.

#### Scenario: Left arrow advances to next page
- **WHEN** the user presses the left arrow key in vertical mode
- **THEN** the display advances to the next page

#### Scenario: Right arrow returns to previous page
- **WHEN** the user presses the right arrow key in vertical mode
- **THEN** the display returns to the previous page

#### Scenario: Left arrow on last page has no effect
- **WHEN** the user presses the left arrow key while on the last page
- **THEN** the display remains on the last page

#### Scenario: Right arrow on first page has no effect
- **WHEN** the user presses the right arrow key while on the first page
- **THEN** the display remains on the first page

### Requirement: Search highlight in vertical mode
The system SHALL highlight search query matches in vertical text mode by applying a distinct background color to matching characters.

#### Scenario: Highlight match in vertical text
- **WHEN** a search query is active and matches text in vertical display mode
- **THEN** the matching characters are highlighted with a distinct background color

#### Scenario: Highlight spans across column boundary
- **WHEN** a search query match spans characters that are split across two columns
- **THEN** the matching characters in both columns are highlighted
