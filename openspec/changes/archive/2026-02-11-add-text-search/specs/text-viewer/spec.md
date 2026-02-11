## MODIFIED Requirements

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

## ADDED Requirements

### Requirement: Search keyboard shortcut integration
The text viewer SHALL support Cmd+F (macOS) / Ctrl+F (Windows/Linux) keyboard shortcut to initiate a search using the currently selected text.

#### Scenario: Keyboard shortcut triggers search with selected text
- **WHEN** the user has selected text and presses Cmd+F (macOS) or Ctrl+F (Windows/Linux)
- **THEN** the selected text is submitted as a search query to the search feature
