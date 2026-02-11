## ADDED Requirements

### Requirement: Search query highlight in text
The text viewer SHALL highlight all occurrences of the active search query within the displayed text content using a visually distinct background color.

#### Scenario: Highlight all occurrences of search query
- **WHEN** a file is opened from a search result with query "冒険"
- **THEN** all occurrences of "冒険" in the displayed text are highlighted with a distinct background color

#### Scenario: Highlight is case-insensitive
- **WHEN** a search query matches text with different casing
- **THEN** all case-insensitive matches are highlighted

#### Scenario: Highlight clears when search match selection is cleared
- **WHEN** the search match selection is cleared (set to null)
- **THEN** no text is highlighted in the text viewer

### Requirement: Scroll to target line
The text viewer SHALL scroll to make the target line visible when a search match is selected.

#### Scenario: Scroll to matched line position
- **WHEN** a search match at line 42 is selected
- **THEN** the text viewer scrolls so that line 42 is visible within the viewport

#### Scenario: No scroll when no match is selected
- **WHEN** a file is opened from the file browser (not from search results)
- **THEN** the text viewer displays from the beginning of the file without scrolling

#### Scenario: Scroll updates when selecting different match in same file
- **WHEN** the user selects a different match line within the same file (e.g., from line 42 to line 100)
- **THEN** the text viewer scrolls to make the newly selected line visible
