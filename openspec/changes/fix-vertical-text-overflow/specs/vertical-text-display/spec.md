## MODIFIED Requirements

### Requirement: Vertical text pagination
The system SHALL display vertical text in pages rather than as a scrollable area. Page boundaries SHALL be calculated dynamically based on both the available width and height of the display area. The pagination SHALL account for the fact that a single logical line (newline-separated text) may occupy multiple visual columns when its character count exceeds the available vertical height. Character dimensions (width and height) used for pagination calculations SHALL be measured from actual font metrics using TextPainter with a representative CJK character, rather than estimated from fontSize alone, to ensure pagination matches the Wrap widget's rendering across all font families and sizes. The maximum columns per page calculation SHALL account for the Wrap widget's runSpacing being applied on both sides of column-break sentinel widgets, resulting in an effective inter-column spacing of `2 * runSpacing` rather than `1 * runSpacing`. The vertical text display area SHALL be clipped to prevent any overflow from becoming visible beyond the display boundaries.

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
- **THEN** the calculation SHALL use the formula `n = floor((availableWidth + 2 * runSpacing) / (charWidth + 2 * runSpacing))` to account for the double runSpacing caused by column-break sentinel widgets in the Wrap layout

#### Scenario: Display area is clipped to prevent overflow
- **WHEN** the vertical text page is rendered
- **THEN** the display area SHALL be clipped so that any content exceeding the boundaries is not visible to the user
