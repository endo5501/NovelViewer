## ADDED Requirements

### Requirement: Full-text search across directory
The system SHALL search all text files in the current directory for a given search query using case-insensitive string matching.

#### Scenario: Search finds matches in multiple files
- **WHEN** a search query is executed against a directory containing multiple text files with matching content
- **THEN** the system returns search results grouped by file, each containing the file name, file path, and a list of matches

#### Scenario: Search finds no matches
- **WHEN** a search query is executed and no text files contain the search term
- **THEN** the system returns an empty result set

#### Scenario: Search is case-insensitive
- **WHEN** a search query "テスト" is executed against a file containing "テスト" and "テスト文字"
- **THEN** both occurrences are included in the search results

### Requirement: Search match context
Each search match SHALL include the surrounding text (context) to help the user understand where the match occurs.

#### Scenario: Match includes surrounding context
- **WHEN** a search match is found within a line of text
- **THEN** the result includes the line number and the text of the line containing the match

### Requirement: Search trigger via keyboard shortcut
The user SHALL be able to trigger a search of the currently selected text by pressing Cmd+F (macOS) or Ctrl+F (Windows/Linux).

#### Scenario: Trigger search with Cmd+F on macOS
- **WHEN** the user has selected text in the text viewer and presses Cmd+F
- **THEN** the selected text is used as the search query and search is executed against the current directory

#### Scenario: Trigger search with Ctrl+F on Windows/Linux
- **WHEN** the user has selected text in the text viewer and presses Ctrl+F
- **THEN** the selected text is used as the search query and search is executed against the current directory

#### Scenario: Trigger search with no text selected
- **WHEN** the user presses Cmd+F or Ctrl+F without selecting any text
- **THEN** no search is executed and the search results remain unchanged

### Requirement: Search results display
The system SHALL display search results in the lower section of the right column, grouped by file name with match context.

#### Scenario: Display search results grouped by file
- **WHEN** search results are available
- **THEN** the lower section of the right column displays results grouped by file name, with each match showing its line number and context text

#### Scenario: Display loading state during search
- **WHEN** a search is in progress
- **THEN** a loading indicator is displayed in the search results area

#### Scenario: Display empty state when no results
- **WHEN** a search returns no results
- **THEN** a message indicating no results were found is displayed

#### Scenario: Display initial state before any search
- **WHEN** no search has been executed yet
- **THEN** the search results area displays a placeholder message

### Requirement: Navigate to file from search result
The user SHALL be able to click on a file name in the search results to open that file in the text viewer.

#### Scenario: Click file name to open file
- **WHEN** the user clicks on a file name in the search results
- **THEN** the corresponding file is opened in the text viewer (center column)

### Requirement: Search results sorted by file name
The system SHALL sort search results by file name using numeric prefix ordering, consistent with the file browser's sort order.

#### Scenario: Results sorted by numeric prefix
- **WHEN** search results contain files named "1_chapter.txt", "10_chapter.txt", "2_chapter.txt"
- **THEN** the results are displayed in order: "1_chapter.txt", "2_chapter.txt", "10_chapter.txt"

#### Scenario: Non-numeric files sorted alphabetically after numeric files
- **WHEN** search results contain files named "2_chapter.txt", "appendix.txt", "1_chapter.txt"
- **THEN** the results are displayed in order: "1_chapter.txt", "2_chapter.txt", "appendix.txt"

### Requirement: Navigate to match line from search result
The user SHALL be able to click on a match line in the search results to open the corresponding file and navigate to the matched line.

#### Scenario: Click match line to open file and set target line
- **WHEN** the user clicks on a match line showing "L42: 検索されたテキスト" in the search results
- **THEN** the corresponding file is opened in the text viewer and the target line number (42) is communicated to the text viewer along with the search query

#### Scenario: Click match line in already-opened file
- **WHEN** the user clicks on a match line belonging to the file that is already displayed in the text viewer
- **THEN** the target line number is updated and the text viewer navigates to the new line position

### Requirement: Search state management
The system SHALL manage search query and results through Riverpod providers, reacting to changes in search query or current directory.

#### Scenario: Search re-executes when directory changes
- **WHEN** the user navigates to a different directory while a search query is active
- **THEN** the search is re-executed against the new directory

#### Scenario: Search clears when query is cleared
- **WHEN** the search query is cleared (set to null)
- **THEN** the search results are cleared and the placeholder state is shown
