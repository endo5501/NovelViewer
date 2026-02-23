## MODIFIED Requirements

### Requirement: Vertical text pagination
The system SHALL display vertical text in pages rather than as a scrollable area. Page boundaries SHALL be calculated dynamically based on both the available width and height of the display area. The pagination SHALL account for the fact that a single logical line (newline-separated text) may occupy multiple visual columns when its character count exceeds the available vertical height. Character dimensions (width and height) used for pagination calculations SHALL be measured from actual font metrics using TextPainter with a representative CJK character, rather than estimated from fontSize alone, to ensure pagination matches the Wrap widget's rendering across all font families and sizes. The maximum columns per page calculation SHALL account for the Wrap widget's runSpacing being applied on both sides of column-break sentinel widgets, resulting in an effective inter-column spacing of `2 * runSpacing` rather than `1 * runSpacing`. The `VerticalTextViewer` SHALL accept a `columnSpacing` parameter and use it in pagination calculations instead of a hardcoded constant. The vertical text display area SHALL be clipped to prevent any overflow from becoming visible beyond the display boundaries. Column character counts SHALL NOT exceed `charsPerColumn` but MAY be shorter (typically by 1 character) due to kinsoku push-out adjustments. The pagination SHALL compute a global text offset for each page based on the original text line structure. The per-page text offset SHALL count only actual text characters (PlainTextSegment.text.length and RubyTextSegment.base.length) and original newlines between lines, and SHALL NOT include synthetic newline separators inserted between wrapped columns of the same line. The computed per-page text offset SHALL be passed to each VerticalTextPage as a `pageStartTextOffset` property. When the VerticalTextViewer receives updated widget properties that do not change the segments list (reference equality), it SHALL NOT reset the current page number.

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

#### Scenario: Per-page text offset excludes synthetic newlines
- **WHEN** a single logical line wraps into 3 visual columns on page 1 with 2 synthetic newline separators
- **THEN** the text offset for page 2 SHALL equal the total text character count of page 1's original content (excluding the 2 synthetic newlines), not the page segment character count

#### Scenario: Per-page text offset is passed to VerticalTextPage
- **WHEN** a VerticalTextPage is rendered for page N
- **THEN** the page SHALL receive a `pageStartTextOffset` property equal to the sum of text characters on all preceding pages (excluding synthetic column-separator newlines)

#### Scenario: Page number is preserved across non-segment widget updates
- **WHEN** the VerticalTextViewer receives an update where only `ttsHighlightStart` or `ttsHighlightEnd` changed but the segments reference is identical
- **THEN** the current page number SHALL NOT be reset to 0

## ADDED Requirements

### Requirement: TTS highlight offset mapping in vertical pages
The VerticalTextPage SHALL correctly compute TTS highlights for any page by converting global TTS text offsets to page-local offsets using the `pageStartTextOffset` property. The TTS highlight computation SHALL count only actual text characters (excluding synthetic newline column separators) when tracking the local text offset, ensuring the highlight position remains accurate regardless of column wrapping.

#### Scenario: TTS highlight on page 1 with no column wrapping
- **WHEN** TTS plays a sentence with TextRange(0, 10) and the text is on page 1 (pageStartTextOffset=0) with no column wrapping
- **THEN** characters at local text offsets 0-9 SHALL be highlighted with green background

#### Scenario: TTS highlight on page 1 with column wrapping
- **WHEN** TTS plays a sentence with TextRange(12, 17) on page 1 where a long line wraps into multiple columns with synthetic newline separators between them
- **THEN** the highlight SHALL correctly identify characters at text offset 12-16, and synthetic newline entries SHALL NOT cause the highlight to drift

#### Scenario: TTS highlight on page 2
- **WHEN** TTS plays a sentence with TextRange(200, 210) and the viewer is on page 2 with pageStartTextOffset=180
- **THEN** characters at local text offsets 20-29 (200-180 to 210-180) SHALL be highlighted

#### Scenario: TTS highlight range outside current page
- **WHEN** TTS plays a sentence with TextRange(50, 60) but the viewer is on page 3 with pageStartTextOffset=300
- **THEN** no characters SHALL be highlighted on this page

#### Scenario: TTS highlight with Ruby text on wrapped columns
- **WHEN** TTS plays a sentence that spans Ruby text entries across wrapped columns with synthetic newline separators
- **THEN** the Ruby text base characters within the TTS range SHALL be correctly identified for highlighting, and synthetic newlines SHALL not shift the offset calculation
