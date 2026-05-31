## MODIFIED Requirements

### Requirement: Selected text extraction in vertical mode
The system SHALL extract the original (unmapped) text from the selected range and store it in the application state via `selectedTextProvider`. For ruby-annotated text, the base text (e.g., kanji) SHALL be used as the selected text content. When the selected range crosses a "visual line break" inserted by pagination to wrap a long line across columns, the system SHALL NOT insert a newline character at that boundary, so the extracted text remains a continuous string. A "real" paragraph break (corresponding to a `\n` in the original text) SHALL still produce a newline in the extracted text. The system SHALL distinguish the two using the set of real line-break entries (`lineBreakEntryIndices`); when that set is not provided, every newline entry SHALL be treated as a real break for backward compatibility.

#### Scenario: Selected text is stored in application state
- **WHEN** the user completes a text selection in vertical mode
- **THEN** the selected text is stored in `selectedTextProvider` and accessible to other features (e.g., search)

#### Scenario: Ruby text selection extracts base text
- **WHEN** the user selects a range that includes ruby-annotated text
- **THEN** the extracted text contains the base text (e.g., kanji), not the ruby annotation

#### Scenario: Mapped characters are extracted as originals
- **WHEN** the user selects text that includes vertically mapped characters (e.g., `︒` displayed for `。`)
- **THEN** the extracted text contains the original characters (e.g., `。`), not the display-mapped characters

#### Scenario: Selection cleared updates provider
- **WHEN** the selection is cleared (by tap or page change)
- **THEN** `selectedTextProvider` is set to null

#### Scenario: Selection crossing a visual column break has no newline
- **WHEN** the user selects a word that straddles a visual line break inserted to wrap a long line across columns (e.g. "アリ" at the end of one column and "ス" at the top of the next column, where that boundary is a visual break)
- **THEN** the extracted text is the continuous string "アリス" with no newline character inserted at the column boundary

#### Scenario: Selection crossing a real paragraph break keeps the newline
- **WHEN** the user selects a range that spans a real paragraph break (a `\n` present in the original text)
- **THEN** the extracted text contains a newline character at that boundary
