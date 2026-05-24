## MODIFIED Requirements

### Requirement: Scroll to target line
In horizontal display mode, the text viewer SHALL scroll to make the target line visible when a search match is selected. The scroll target position SHALL be computed from the actual rendered text layout (accounting for ruby annotations, automatic line wrapping, font family metrics, and rendering padding), not from a fixed line-height × line-number formula. In vertical display mode, the viewer SHALL navigate to the page containing the matched text.

#### Scenario: Scroll to matched line position in horizontal mode
- **WHEN** a search match at line 42 is selected and the display mode is horizontal
- **THEN** the text viewer scrolls so that line 42 is visible within the viewport, with the line positioned at the top of the visible area (within ±half a line of error)

#### Scenario: Accurate scroll for lines containing ruby annotations
- **WHEN** a search match is selected on a line that itself or earlier lines contain ruby annotations
- **AND** the display mode is horizontal
- **THEN** the text viewer scrolls to the correct Y position taking into account the increased line height caused by ruby annotations in the lines above the target

#### Scenario: Accurate scroll for wrapped long lines
- **WHEN** a search match is selected and one or more lines before the target line are long enough to wrap to multiple visual rows in the current viewport width
- **AND** the display mode is horizontal
- **THEN** the text viewer scrolls to the correct Y position taking into account the additional visual rows caused by line wrapping

#### Scenario: Accurate scroll across different font families
- **WHEN** a search match is selected with a font family whose default text metrics differ from the application default
- **AND** the display mode is horizontal
- **THEN** the text viewer scrolls to the correct Y position based on the actual line heights produced by that font family

#### Scenario: Navigate to matched page in vertical mode
- **WHEN** a search match is selected and the display mode is vertical
- **THEN** the text viewer navigates to the page containing the matched text

#### Scenario: No scroll when no match is selected
- **WHEN** a file is opened from the file browser (not from search results)
- **THEN** the text viewer displays from the beginning of the file without scrolling

#### Scenario: Scroll updates when selecting different match in same file
- **WHEN** the user selects a different match line within the same file (e.g., from line 42 to line 100)
- **THEN** the text viewer scrolls to make the newly selected line visible
