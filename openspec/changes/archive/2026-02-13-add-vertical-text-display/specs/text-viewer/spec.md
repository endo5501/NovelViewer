## MODIFIED Requirements

### Requirement: Text file display
The system SHALL read and display the full content of the selected text file in the center column. When the display mode is horizontal, text SHALL be rendered with horizontal (left-to-right) layout. When the display mode is vertical, text SHALL be rendered using the vertical text display widget. HTML ruby tags in the content SHALL be rendered as ruby annotations in both display modes.

#### Scenario: Display text file content in horizontal mode
- **WHEN** a text file is selected from the file browser and the display mode is horizontal
- **THEN** the entire content of the file is displayed in the center column in horizontal layout

#### Scenario: Display text file content in vertical mode
- **WHEN** a text file is selected from the file browser and the display mode is vertical
- **THEN** the entire content of the file is displayed in the center column in vertical layout with pagination

#### Scenario: Display UTF-8 encoded text
- **WHEN** a UTF-8 encoded text file containing Japanese characters is selected
- **THEN** the text is displayed correctly without garbled characters

#### Scenario: Display text with ruby tags
- **WHEN** a text file containing HTML ruby tags (e.g., `<ruby>漢字<rp>(</rp><rt>かんじ</rt><rp>)</rp></ruby>`) is selected
- **THEN** the ruby annotations are rendered visually (above base text in horizontal mode, to the right of base text in vertical mode), not as raw HTML strings

### Requirement: Scrollable text area
In horizontal display mode, the text display area SHALL be scrollable to accommodate text files of any length. In vertical display mode, pagination SHALL be used instead of scrolling.

#### Scenario: Long text file is scrollable in horizontal mode
- **WHEN** a text file whose content exceeds the visible area is displayed in horizontal mode
- **THEN** the user can scroll vertically to read the entire content

#### Scenario: Long text file is paginated in vertical mode
- **WHEN** a text file whose content exceeds the visible area is displayed in vertical mode
- **THEN** the text is displayed in pages navigable by arrow keys

### Requirement: Scroll to target line
In horizontal display mode, the text viewer SHALL scroll to make the target line visible when a search match is selected. In vertical display mode, the viewer SHALL navigate to the page containing the matched text.

#### Scenario: Scroll to matched line position in horizontal mode
- **WHEN** a search match at line 42 is selected and the display mode is horizontal
- **THEN** the text viewer scrolls so that line 42 is visible within the viewport

#### Scenario: Navigate to matched page in vertical mode
- **WHEN** a search match is selected and the display mode is vertical
- **THEN** the text viewer navigates to the page containing the matched text
