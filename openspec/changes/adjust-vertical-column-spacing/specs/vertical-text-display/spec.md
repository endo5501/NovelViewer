## MODIFIED Requirements

### Requirement: Vertical text rendering
The system SHALL render text content in vertical writing mode (top-to-bottom, right-to-left columns) using a Wrap widget with vertical axis direction and RTL text direction. Each character SHALL be rendered individually as a separate widget within the Wrap layout. Each character widget SHALL be wrapped in a fixed-width container (`SizedBox`) with width equal to the current font size, and the character SHALL be horizontally centered within that container using a `Center` widget. This ensures consistent column alignment regardless of platform-specific font metrics differences. Characters SHALL be rendered with compact vertical spacing by setting the TextStyle `height` property to approximately 1.1 and minimizing the Wrap `spacing` to avoid excessive gaps between characters. The Wrap widget's `runSpacing` SHALL use the column spacing value from the settings (default `8.0`) instead of a hardcoded constant. The `VerticalTextPage` SHALL accept a `columnSpacing` parameter to control the `runSpacing` value. The Wrap widget SHALL be wrapped in a GestureDetector to support text selection via drag gestures. The `VerticalTextPage` SHALL accept an `onSelectionChanged` callback. Each character widget SHALL be assigned a `GlobalKey` to enable post-layout collection of actual rendered rectangles for accurate hit testing.

#### Scenario: Text is displayed vertically
- **WHEN** the display mode is set to vertical
- **THEN** characters are arranged from top to bottom within each column, and columns flow from right to left

#### Scenario: Line breaks create new columns
- **WHEN** the text content contains newline characters in vertical mode
- **THEN** a new column starts at the position of each newline, with subsequent text continuing from the top of the new column

#### Scenario: Empty line creates a visible empty column
- **WHEN** the text content contains consecutive newline characters (blank line) in vertical mode
- **THEN** an empty column SHALL be rendered with the same width as a text column (one character width), creating visible space between adjacent text columns

#### Scenario: Column overflow wraps to next column
- **WHEN** a column of text exceeds the available vertical height
- **THEN** the remaining characters wrap to a new column to the left

#### Scenario: GestureDetector wraps the vertical text layout
- **WHEN** the vertical text page is rendered
- **THEN** a GestureDetector is present as a parent of the Wrap widget to capture pan gestures for text selection

#### Scenario: Characters are horizontally centered in fixed-width containers
- **WHEN** any character is rendered in vertical text mode
- **THEN** the character SHALL be placed inside a SizedBox with width equal to the current font size, and the character SHALL be horizontally centered within that SizedBox

#### Scenario: Column alignment is consistent across platforms
- **WHEN** vertical text is rendered on different platforms (macOS, Windows)
- **THEN** characters within each column SHALL be aligned vertically in a straight line regardless of individual character width differences in the platform's font

#### Scenario: Ruby base and annotation characters use fixed-width containers
- **WHEN** ruby text (base and annotation) is rendered in vertical mode
- **THEN** each base character SHALL be wrapped in a SizedBox with width equal to the base font size, and each ruby annotation character SHALL be wrapped in a SizedBox with width equal to the ruby font size, both horizontally centered

#### Scenario: Column spacing uses configurable value
- **WHEN** the vertical text page is rendered with a `columnSpacing` parameter
- **THEN** the Wrap widget's `runSpacing` SHALL be set to the provided `columnSpacing` value

#### Scenario: Default column spacing
- **WHEN** the vertical text page is rendered without an explicit `columnSpacing` parameter
- **THEN** the Wrap widget's `runSpacing` SHALL use the default value of `8.0`

### Requirement: Vertical text pagination
The system SHALL display vertical text in pages rather than as a scrollable area. Page boundaries SHALL be calculated dynamically based on both the available width and height of the display area. The pagination SHALL account for the fact that a single logical line (newline-separated text) may occupy multiple visual columns when its character count exceeds the available vertical height. Character dimensions (width and height) used for pagination calculations SHALL be measured from actual font metrics using TextPainter with a representative CJK character, rather than estimated from fontSize alone, to ensure pagination matches the Wrap widget's rendering across all font families and sizes. The maximum columns per page calculation SHALL account for the Wrap widget's runSpacing being applied on both sides of column-break sentinel widgets, resulting in an effective inter-column spacing of `2 * runSpacing` rather than `1 * runSpacing`. The `VerticalTextViewer` SHALL accept a `columnSpacing` parameter and use it in pagination calculations instead of a hardcoded constant. The vertical text display area SHALL be clipped to prevent any overflow from becoming visible beyond the display boundaries. Column character counts SHALL NOT exceed `charsPerColumn` but MAY be shorter (typically by 1 character) due to kinsoku push-out adjustments.

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

#### Scenario: Empty columns from blank lines occupy full column width
- **WHEN** the text contains blank lines (paragraph separators) that produce empty columns
- **THEN** the pagination SHALL treat empty columns with the same width as non-empty columns (one character width), so that blank lines are visually represented as empty space between text columns
- **AND** the actual rendered width of all columns on a page SHALL be less than or equal to the available display width

#### Scenario: Page navigation with blank lines remains accurate
- **WHEN** the user navigates to a specific line number in text containing blank lines
- **THEN** the viewer SHALL correctly identify which page contains the target line, accounting for the columns per page

#### Scenario: Columns with kinsoku adjustment fit within page width
- **WHEN** the pagination groups columns into pages and some columns have variable character counts due to kinsoku processing
- **THEN** the pagination SHALL use the actual character count of each column for width calculation, ensuring columns fit within the available page width

#### Scenario: Pagination uses configurable column spacing
- **WHEN** the `VerticalTextViewer` is rendered with a `columnSpacing` parameter
- **THEN** the pagination calculation SHALL use the provided `columnSpacing` value instead of a hardcoded constant

#### Scenario: Column spacing change triggers re-pagination
- **WHEN** the column spacing setting is changed while vertical text is displayed
- **THEN** the pagination SHALL be recalculated with the new column spacing value and the display SHALL update accordingly
