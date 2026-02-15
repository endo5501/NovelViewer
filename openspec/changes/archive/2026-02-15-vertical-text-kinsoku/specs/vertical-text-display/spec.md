## ADDED Requirements

### Requirement: Kinsoku processing for column splitting
The system SHALL apply Japanese line-breaking rules (禁則処理) when splitting text into vertical columns. Line-head forbidden characters (行頭禁則文字) SHALL NOT appear as the first character of a column. Line-end forbidden characters (行末禁則文字) SHALL NOT appear as the last character of a column. The system SHALL use the "push-out" (追い出し) method to resolve violations: when a line-head forbidden character would appear at the start of a new column, the last character of the current column SHALL be moved to the start of the next column (making the current column one character shorter), so the forbidden character becomes the second character of the next column rather than the first. When a line-end forbidden character appears at the end of a column, it SHALL be moved to the start of the next column. All columns SHALL have at most `charsPerColumn` characters to ensure compatibility with the Wrap widget's vertical height constraint. Kinsoku character sets and判定 functions SHALL be defined in a separate data-layer module (`kinsoku.dart`) alongside other character-processing utilities.

Line-head forbidden characters (行頭禁則文字):
- Punctuation: `。、，．,.`
- Closing brackets: `）」』】〕｝〉》﹂﹄︶﹈︸﹀︼︺︘︾)]}`
- Middle dots and colons: `・：；`
- Exclamation and question marks: `！？!?`
- Long vowel mark: `ー`
- Leaders: `…‥`
- Small kana: `ぁぃぅぇぉっゃゅょゎァィゥェォッャュョヮヵヶ`

Line-end forbidden characters (行末禁則文字):
- Opening brackets: `（「『【〔｛〈《﹁﹃︵﹇︷︿︻︹︗︽([{`

RubyTextSegment SHALL be treated as an indivisible unit during kinsoku processing. The first base character of a RubyTextSegment SHALL be used for line-head forbidden character check, and the last base character SHALL be used for line-end forbidden character check.

#### Scenario: Line-head forbidden character triggers push-out of last column character
- **WHEN** a column split would place a line-head forbidden character (e.g., `。`, `、`, `）`, `」`) as the first character of a new column
- **THEN** the system SHALL move the last character of the current column to the start of the next column, making the current column one character shorter than `charsPerColumn`, so the forbidden character becomes the second character of the next column

#### Scenario: Line-end forbidden character is pushed to next column
- **WHEN** a column is filled to `charsPerColumn` and the last character is a line-end forbidden character (e.g., `（`, `「`, `『`)
- **THEN** the system SHALL move that character to the start of the next column, making the current column one character shorter than `charsPerColumn`

#### Scenario: Consecutive line-head forbidden characters are handled by push-out
- **WHEN** a column split would place multiple consecutive line-head forbidden characters (e.g., `。」` or `！？」`) at the start of a new column
- **THEN** the system SHALL push the last character of the current column to the next column, and the consecutive forbidden characters SHALL naturally follow as non-first characters in the next column

#### Scenario: No kinsoku violation at column boundary
- **WHEN** a column split occurs and neither the next character is line-head forbidden nor the last character is line-end forbidden
- **THEN** the column split SHALL occur at the standard `charsPerColumn` boundary without adjustment

#### Scenario: Kinsoku with RubyTextSegment
- **WHEN** a RubyTextSegment would begin a new column and the first base character of that segment is a line-head forbidden character
- **THEN** the last character of the current column SHALL be moved to the start of the next column, so the RubyTextSegment becomes the second entry of the next column

#### Scenario: First column is not affected by kinsoku
- **WHEN** the first character of the first column in a line is a line-head forbidden character
- **THEN** no adjustment SHALL be made because there is no previous column to push the character into

#### Scenario: Column at end of line is not affected by line-end kinsoku
- **WHEN** the last column of a line ends with a line-end forbidden character and no more text follows in the line
- **THEN** no adjustment SHALL be made because no subsequent column exists within the same line

## MODIFIED Requirements

### Requirement: Vertical text pagination
The system SHALL display vertical text in pages rather than as a scrollable area. Page boundaries SHALL be calculated dynamically based on both the available width and height of the display area. The pagination SHALL account for the fact that a single logical line (newline-separated text) may occupy multiple visual columns when its character count exceeds the available vertical height. Character dimensions (width and height) used for pagination calculations SHALL be measured from actual font metrics using TextPainter with a representative CJK character, rather than estimated from fontSize alone, to ensure pagination matches the Wrap widget's rendering across all font families and sizes. The maximum columns per page calculation SHALL account for the Wrap widget's runSpacing being applied on both sides of column-break sentinel widgets, resulting in an effective inter-column spacing of `2 * runSpacing` rather than `1 * runSpacing`. The vertical text display area SHALL be clipped to prevent any overflow from becoming visible beyond the display boundaries. Column character counts SHALL NOT exceed `charsPerColumn` but MAY be shorter (typically by 1 character) due to kinsoku push-out adjustments.

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

#### Scenario: Pagination uses measured font metrics
- **WHEN** the pagination calculates column widths and characters per column
- **THEN** the character width and height are obtained by measuring a representative character ('あ') with the current TextStyle via TextPainter, not by estimating from fontSize

#### Scenario: Pagination remains accurate across font families
- **WHEN** the user switches between different font families (e.g., system default, Hiragino Mincho, YuGothic)
- **THEN** the pagination recalculates using the new font's actual metrics and text does not overflow the display area

#### Scenario: Pagination remains accurate across font sizes
- **WHEN** the user changes font size (anywhere in the 10.0-32.0 range)
- **THEN** the pagination recalculates using the actual rendered dimensions and text does not overflow the display area

#### Scenario: Column count accounts for sentinel runSpacing
- **WHEN** the pagination calculates the maximum number of columns per page
- **THEN** the calculation SHALL account for the double runSpacing caused by column-break sentinel widgets in the Wrap layout

#### Scenario: Display area is clipped to prevent overflow
- **WHEN** the vertical text page is rendered
- **THEN** the display area SHALL be clipped so that any content exceeding the boundaries is not visible to the user

#### Scenario: Empty columns from blank lines do not waste horizontal space
- **WHEN** the text contains blank lines (paragraph separators) that produce empty columns
- **THEN** the pagination SHALL account for the fact that empty columns occupy zero character width in the Wrap layout, packing more columns per page to minimize unused horizontal space
- **AND** the actual rendered width of all columns on a page SHALL be less than or equal to the available display width

#### Scenario: Width-based greedy packing for page boundaries
- **WHEN** the pagination groups columns into pages
- **THEN** the pagination SHALL use a width-based greedy packing algorithm that accumulates the actual rendered width of each column (charWidth for non-empty columns, zero for empty columns) plus sentinel runSpacing gaps, rather than a fixed column count per page
- **AND** each page SHALL contain as many columns as can fit within the available width

#### Scenario: Page navigation with blank lines remains accurate
- **WHEN** the user navigates to a specific line number in text containing blank lines
- **THEN** the viewer SHALL correctly identify which page contains the target line, accounting for variable column counts per page due to width-based packing

#### Scenario: Columns with kinsoku adjustment fit within page width
- **WHEN** the pagination groups columns into pages and some columns have variable character counts due to kinsoku processing
- **THEN** the width-based greedy packing SHALL use the actual character count of each column for width calculation, ensuring columns fit within the available page width
