## ADDED Requirements

### Requirement: Text file display
The system SHALL read and display the full content of the selected text file in the center column with horizontal (left-to-right) text layout.

#### Scenario: Display text file content
- **WHEN** a text file is selected from the file browser
- **THEN** the entire content of the file is displayed in the center column in horizontal layout

#### Scenario: Display UTF-8 encoded text
- **WHEN** a UTF-8 encoded text file containing Japanese characters is selected
- **THEN** the text is displayed correctly without garbled characters

### Requirement: Scrollable text area
The text display area SHALL be scrollable to accommodate text files of any length.

#### Scenario: Long text file is scrollable
- **WHEN** a text file whose content exceeds the visible area is displayed
- **THEN** the user can scroll vertically to read the entire content

### Requirement: Text selection
The user SHALL be able to select text within the displayed content by click-and-drag.

#### Scenario: User selects text
- **WHEN** the user clicks and drags over text in the center column
- **THEN** the selected text is highlighted

### Requirement: No file selected state
The center column SHALL display a placeholder message when no file is currently selected.

#### Scenario: Application starts without file selection
- **WHEN** the application launches and no file has been selected
- **THEN** the center column displays a message such as "ファイルを選択してください"
