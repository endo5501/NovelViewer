## MODIFIED Requirements

### Requirement: Cache summary results in SQLite
The system SHALL store LLM summary results in a `word_summaries` SQLite table, keyed by folder name, word, and summary type (spoiler/no_spoiler). For BOTH summary types the system SHALL also persist `source_file` set to the file the user was viewing when the analysis ran, so that subsequent UI features (e.g., the analysis history panel) can resolve a jump target back into the text. Existing rows whose `source_file` is `NULL` (legacy spoiler entries written before this change) SHALL be left untouched; the column is populated only on new inserts and on re-analysis writes.

#### Scenario: Save spoiler summary to database with source file
- **WHEN** LLM analysis completes for the word "アリス" in folder "my_novel" with summary type "spoiler" while viewing file "060_chapter.txt"
- **THEN** the summary is saved to the `word_summaries` table with folder_name="my_novel", word="アリス", summary_type="spoiler", source_file="060_chapter.txt", and current timestamps

#### Scenario: Save no-spoiler summary with source file
- **WHEN** LLM analysis completes for the word "アリス" in folder "my_novel" with summary type "no_spoiler" while viewing file "040_chapter.txt"
- **THEN** the summary is saved with source_file="040_chapter.txt" to track the reading position

#### Scenario: Legacy spoiler row with NULL source_file is preserved
- **WHEN** a spoiler row exists in `word_summaries` from before this change with `source_file=NULL`
- **THEN** that row SHALL remain in the table unchanged until it is re-analyzed; reading it back SHALL yield `source_file=NULL`

#### Scenario: Re-analysis updates source_file for spoiler entries
- **WHEN** the user re-runs spoiler analysis on a word whose existing spoiler row has `source_file=NULL`, while currently viewing "080_chapter.txt"
- **THEN** the updated row SHALL have `source_file="080_chapter.txt"` in addition to the new summary text and `updated_at`

## ADDED Requirements

### Requirement: Minimum word length for cache writes
The system SHALL refuse to write a new `word_summaries` row when the analyzed word is shorter than 2 characters. This SHALL be enforced at the repository layer so that downstream features (mark rendering, history panel) do not have to filter 1-character entries at render time.

#### Scenario: 1-character word write is rejected
- **WHEN** the analysis pipeline attempts to save a summary for the word "の"
- **THEN** the save SHALL be rejected without writing a row, and the caller SHALL receive a clear failure signal (exception or error result)

#### Scenario: 2-character word write succeeds
- **WHEN** the analysis pipeline saves a summary for the word "聖印"
- **THEN** the save SHALL succeed normally
