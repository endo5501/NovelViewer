## MODIFIED Requirements

### Requirement: Search match context
Each search match SHALL include the surrounding text (context) to help the user understand where the match occurs. Additionally, the system SHALL support retrieving extended context (multiple lines before and after the match) for LLM prompt construction.

#### Scenario: Match includes surrounding context
- **WHEN** a search match is found within a line of text
- **THEN** the result includes the line number and the text of the line containing the match

#### Scenario: Search with extended context lines
- **WHEN** a search is executed with contextLines parameter set to 2
- **THEN** each match includes the matched line plus 2 lines before and 2 lines after the match, concatenated as a single context string

#### Scenario: Extended context at file boundaries
- **WHEN** a match is found on line 1 of a file with contextLines=2
- **THEN** the context includes line 1 and the 2 lines after it (no lines before since it's at the start of the file)

#### Scenario: Extended context with overlapping matches
- **WHEN** two matches are found on adjacent lines (e.g., line 5 and line 6) with contextLines=2
- **THEN** each match returns its own context independently (deduplication of context is handled by the caller)
