## MODIFIED Requirements

### Requirement: Text file display
The system SHALL read and display the full content of the selected text file in the center column with horizontal (left-to-right) text layout. HTML ruby tags in the content SHALL be rendered as ruby annotations (furigana above base text) instead of raw HTML strings.

#### Scenario: Display text file content
- **WHEN** a text file is selected from the file browser
- **THEN** the entire content of the file is displayed in the center column in horizontal layout

#### Scenario: Display UTF-8 encoded text
- **WHEN** a UTF-8 encoded text file containing Japanese characters is selected
- **THEN** the text is displayed correctly without garbled characters

#### Scenario: Display text with ruby tags
- **WHEN** a text file containing HTML ruby tags (e.g., `<ruby>漢字<rp>(</rp><rt>かんじ</rt><rp>)</rp></ruby>`) is selected
- **THEN** the ruby annotations are rendered visually above the base text, not as raw HTML strings

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
