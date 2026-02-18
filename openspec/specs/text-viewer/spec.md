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

### Requirement: TTS playback controls in text viewer
The text viewer panel SHALL display a play/stop button for TTS playback. When TTS is stopped, a play button SHALL be shown. When TTS is playing or loading, a stop button SHALL be shown. The button SHALL only be enabled when TTS model configuration is valid (model directory path is set). When TTS is in the loading state, a loading indicator SHALL be displayed alongside the stop button.

#### Scenario: Display play button when TTS is stopped
- **WHEN** the text viewer is displayed with valid TTS configuration and TTS is not playing
- **THEN** a play button is visible in the text viewer panel

#### Scenario: Display stop button when TTS is playing
- **WHEN** TTS playback is active
- **THEN** the play button is replaced with a stop button

#### Scenario: Display loading indicator when TTS is generating
- **WHEN** TTS is in the loading state (generating first sentence)
- **THEN** a loading indicator is displayed alongside the stop button

#### Scenario: Disable play button when TTS is not configured
- **WHEN** the TTS model directory path is not set in settings
- **THEN** the play button is disabled (grayed out)

#### Scenario: Press play to start TTS
- **WHEN** the user presses the play button
- **THEN** TTS playback begins from the appropriate start position

#### Scenario: Press stop to halt TTS
- **WHEN** the user presses the stop button during playback
- **THEN** TTS playback stops and the highlight is cleared

### Requirement: TTS highlight rendering in text viewer
The text viewer SHALL render TTS highlights for the currently playing sentence in both horizontal and vertical display modes. The TTS highlight SHALL use a semi-transparent green background (`Colors.green` with opacity 0.3). When a search highlight and TTS highlight overlap on the same character, the search highlight (yellow) SHALL take precedence.

#### Scenario: Render TTS highlight in horizontal mode
- **WHEN** TTS is playing a sentence in horizontal display mode
- **THEN** the characters of the current sentence are rendered with a green semi-transparent background

#### Scenario: Render TTS highlight in vertical mode
- **WHEN** TTS is playing a sentence in vertical display mode
- **THEN** the characters of the current sentence are rendered with a green semi-transparent background

#### Scenario: Search highlight takes precedence over TTS highlight
- **WHEN** a character is within both the TTS highlight range and matches the search query
- **THEN** the search highlight (yellow) is displayed instead of the TTS highlight (green)

#### Scenario: TTS highlight cleared when playback stops
- **WHEN** TTS playback stops
- **THEN** the green TTS highlight is removed from all characters

### Requirement: Stop TTS on user page navigation
The text viewer SHALL stop TTS playback when the user manually navigates pages or scrolls. This includes arrow key presses, swipe gestures, and mouse wheel scrolling. Auto page turns triggered by TTS itself SHALL NOT stop playback.

#### Scenario: Arrow key stops TTS in vertical mode
- **WHEN** the user presses the left or right arrow key during TTS playback in vertical mode
- **THEN** TTS playback stops

#### Scenario: Swipe gesture stops TTS
- **WHEN** the user performs a swipe gesture during TTS playback
- **THEN** TTS playback stops

#### Scenario: Mouse wheel stops TTS
- **WHEN** the user scrolls with the mouse wheel during TTS playback
- **THEN** TTS playback stops

#### Scenario: Auto page turn does not stop TTS
- **WHEN** TTS triggers an automatic page turn to follow the current sentence
- **THEN** TTS playback continues without interruption
