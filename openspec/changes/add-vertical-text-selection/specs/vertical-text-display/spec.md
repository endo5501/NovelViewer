## MODIFIED Requirements

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
