## ADDED Requirements

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
