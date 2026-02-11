## ADDED Requirements

### Requirement: Three-column layout structure
The application SHALL display a three-column layout as its main screen, consisting of a left column (file browser), a center column (text viewer), and a right column (search/summary area).

#### Scenario: All three columns are visible
- **WHEN** the application launches
- **THEN** three columns are displayed side by side separated by vertical dividers

#### Scenario: Center column expands to fill available space
- **WHEN** the window is resized
- **THEN** the center column expands or contracts to fill the remaining space while left and right columns maintain their fixed width

### Requirement: Left column displays file browser
The left column SHALL contain the file browser component for navigating and selecting text files.

#### Scenario: Left column shows file browser
- **WHEN** the application launches
- **THEN** the left column displays the file browser widget

### Requirement: Center column displays text viewer
The center column SHALL display the content of the currently selected text file.

#### Scenario: Center column shows placeholder when no file selected
- **WHEN** no file is selected
- **THEN** the center column displays a placeholder message indicating no file is selected

#### Scenario: Center column shows file content when file selected
- **WHEN** a file is selected from the file browser
- **THEN** the center column displays the content of the selected file

### Requirement: Right column placeholder
The right column SHALL be divided into two sections: an upper section reserved for LLM summary functionality (placeholder) and a lower section for displaying search results.

#### Scenario: Right column displays two sections
- **WHEN** the application launches
- **THEN** the right column displays an upper section with a placeholder for LLM summary and a lower section for search results, separated by a horizontal divider

#### Scenario: Upper section shows LLM summary placeholder
- **WHEN** the application launches
- **THEN** the upper section of the right column displays a placeholder indicating the area is reserved for LLM summary features

#### Scenario: Lower section shows search results area
- **WHEN** the application launches
- **THEN** the lower section of the right column displays the search results area (initially showing a placeholder message)

### Requirement: Settings access
The application SHALL display a settings icon that opens a settings dialog when pressed.

#### Scenario: Settings icon is visible
- **WHEN** the application launches
- **THEN** a settings icon is visible in the application

#### Scenario: Settings dialog opens
- **WHEN** the user presses the settings icon
- **THEN** a settings dialog is displayed (with placeholder content for future configuration)
