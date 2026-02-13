## ADDED Requirements

### Requirement: Vertical text rendering
The system SHALL render text content in vertical writing mode (top-to-bottom, right-to-left columns) using a Wrap widget with vertical axis direction and RTL text direction. Each character SHALL be rendered individually as a separate widget within the Wrap layout. Characters SHALL be rendered with compact vertical spacing by setting the TextStyle `height` property to approximately 1.1 and minimizing the Wrap `spacing` to avoid excessive gaps between characters. The Wrap widget SHALL be wrapped in a GestureDetector to support text selection via drag gestures. The `VerticalTextPage` SHALL accept an `onSelectionChanged` callback. Each character widget SHALL be assigned a `GlobalKey` to enable post-layout collection of actual rendered rectangles for accurate hit testing.

#### Scenario: Text is displayed vertically
- **WHEN** the display mode is set to vertical
- **THEN** characters are arranged from top to bottom within each column, and columns flow from right to left

#### Scenario: Line breaks create new columns
- **WHEN** the text content contains newline characters in vertical mode
- **THEN** a new column starts at the position of each newline, with subsequent text continuing from the top of the new column

#### Scenario: Column overflow wraps to next column
- **WHEN** a column of text exceeds the available vertical height
- **THEN** the remaining characters wrap to a new column to the left

#### Scenario: GestureDetector wraps the vertical text layout
- **WHEN** the vertical text page is rendered
- **THEN** a GestureDetector is present as a parent of the Wrap widget to capture pan gestures for text selection

### Requirement: Vertical character mapping
The system SHALL replace horizontal-specific characters with their vertical writing equivalents when rendering in vertical mode. The mapping SHALL cover the full set defined in the Qiita reference article's VerticalRotated class, plus NovelViewer-specific additions.

#### Scenario: Punctuation is mapped to vertical form
- **WHEN** punctuation characters `。`, `、`, `,`, `､` are encountered in vertical mode
- **THEN** they are rendered as `︒`, `︑`, `︐`, `︑` respectively

#### Scenario: Long vowel marks and dashes are mapped to vertical bar
- **WHEN** any of `ー`, `ｰ`, `-`, `_`, `−`, `－`, `─`, `—` are encountered in vertical mode
- **THEN** they are rendered as `丨` (CJK unified ideograph U+4E28)

#### Scenario: Wave dashes are mapped to vertical form
- **WHEN** `〜` or `～` are encountered in vertical mode
- **THEN** they are rendered as `丨`

#### Scenario: Arrows are rotated 90 degrees
- **WHEN** arrow characters `↑`, `↓`, `←`, `→` are encountered in vertical mode
- **THEN** they are rendered as `→`, `←`, `↑`, `↓` respectively (rotated 90° clockwise)

#### Scenario: Brackets are mapped to vertical forms
- **WHEN** bracket characters are encountered in vertical mode
- **THEN** they are mapped as follows:
  - Corner brackets: `「」｢｣` → `﹁﹂`, `『』` → `﹃﹄`
  - Parentheses: `（）()` → `︵︶`
  - Square brackets: `［］[]` → `﹇﹈`
  - Curly brackets: `｛｝{}` → `︷︸`
  - Lenticular brackets: `【】` → `︻︼`, `〖〗` → `︗︘`
  - Angle brackets: `＜＞<>` → `︿﹀`, `〈〉` → `︿﹀`, `《》` → `︽︾`
  - Tortoise shell brackets: `〔〕` → `︹︺`

#### Scenario: Colons and semicolons are mapped to vertical form
- **WHEN** `：`, `:`, `；`, or `;` are encountered in vertical mode
- **THEN** they are rendered as `︓`, `︓`, `︔`, `︔` respectively

#### Scenario: Equals signs are mapped to vertical form
- **WHEN** `＝` or `=` are encountered in vertical mode
- **THEN** they are rendered as `॥`

#### Scenario: Ellipsis and two-dot leader are mapped to vertical form
- **WHEN** `…` or `‥` are encountered in vertical mode
- **THEN** they are rendered as `︙` or `︰` respectively

#### Scenario: Slash is mapped to vertical form
- **WHEN** `／` is encountered in vertical mode
- **THEN** it is rendered as `＼`

#### Scenario: Space is mapped to ideographic space
- **WHEN** a half-width space `' '` is encountered in vertical mode
- **THEN** it is rendered as a full-width ideographic space `'　'`

#### Scenario: Unmapped characters remain unchanged
- **WHEN** a character without a vertical mapping is encountered in vertical mode
- **THEN** the character is rendered as-is without transformation

### Requirement: Vertical text pagination
The system SHALL display vertical text in pages rather than as a scrollable area. Page boundaries SHALL be calculated dynamically based on both the available width and height of the display area. The pagination SHALL account for the fact that a single logical line (newline-separated text) may occupy multiple visual columns when its character count exceeds the available vertical height.

#### Scenario: Text is split into pages
- **WHEN** the text content exceeds the available display area in vertical mode
- **THEN** the text is divided into pages, each fitting within the display area without overflowing

#### Scenario: Long line spans multiple visual columns
- **WHEN** a single logical line contains more characters than can fit in the available vertical height
- **THEN** the pagination accounts for the multiple visual columns that line will occupy, preventing horizontal overflow

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
