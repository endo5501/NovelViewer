## ADDED Requirements

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

### Requirement: Text selection
The user SHALL be able to select text within the displayed content by click-and-drag. The system SHALL track the currently selected text and make it available for search functionality.

#### Scenario: User selects text
- **WHEN** the user clicks and drags over text in the center column
- **THEN** the selected text is highlighted

#### Scenario: Selected text is tracked
- **WHEN** the user selects text in the text viewer
- **THEN** the selected text value is stored in application state and accessible to other features

#### Scenario: Selection is cleared
- **WHEN** the user clicks elsewhere without dragging or selects different text
- **THEN** the previously tracked selected text is updated accordingly

### Requirement: Search keyboard shortcut integration
The text viewer SHALL support Cmd+F (macOS) / Ctrl+F (Windows/Linux) keyboard shortcut to initiate a search using the currently selected text.

#### Scenario: Keyboard shortcut triggers search with selected text
- **WHEN** the user has selected text and presses Cmd+F (macOS) or Ctrl+F (Windows/Linux)
- **THEN** the selected text is submitted as a search query to the search feature

### Requirement: Search query highlight in text
The text viewer SHALL highlight all occurrences of the active search query within the displayed text content using a visually distinct background color. Highlighting SHALL operate on the visible text (ruby base text and plain text), not on raw HTML tags.

#### Scenario: Highlight all occurrences of search query
- **WHEN** a file is opened from a search result with query "冒険"
- **THEN** all occurrences of "冒険" in the displayed text are highlighted with a distinct background color

#### Scenario: Highlight is case-insensitive
- **WHEN** a search query matches text with different casing
- **THEN** all case-insensitive matches are highlighted

#### Scenario: Highlight clears when search match selection is cleared
- **WHEN** the search match selection is cleared (set to null)
- **THEN** no text is highlighted in the text viewer

#### Scenario: Highlight works with ruby-annotated text
- **WHEN** a search query matches the base text within a ruby annotation
- **THEN** the base text is highlighted with a distinct background color while the ruby annotation remains visible

### Requirement: Scroll to target line
In horizontal display mode, the text viewer SHALL scroll to make the target line visible when a search match is selected. In vertical display mode, the viewer SHALL navigate to the page containing the matched text.

#### Scenario: Scroll to matched line position in horizontal mode
- **WHEN** a search match at line 42 is selected and the display mode is horizontal
- **THEN** the text viewer scrolls so that line 42 is visible within the viewport

#### Scenario: Navigate to matched page in vertical mode
- **WHEN** a search match is selected and the display mode is vertical
- **THEN** the text viewer navigates to the page containing the matched text

#### Scenario: No scroll when no match is selected
- **WHEN** a file is opened from the file browser (not from search results)
- **THEN** the text viewer displays from the beginning of the file without scrolling

#### Scenario: Scroll updates when selecting different match in same file
- **WHEN** the user selects a different match line within the same file (e.g., from line 42 to line 100)
- **THEN** the text viewer scrolls to make the newly selected line visible

### Requirement: No file selected state
The center column SHALL display a placeholder message when no file is currently selected.

#### Scenario: Application starts without file selection
- **WHEN** the application launches and no file has been selected
- **THEN** the center column displays a message such as "ファイルを選択してください"
