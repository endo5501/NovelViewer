## ADDED Requirements

### Requirement: Cache summary results in SQLite
The system SHALL store LLM summary results in a `word_summaries` SQLite table, keyed by folder name, word, and summary type (spoiler/no_spoiler).

#### Scenario: Save spoiler summary to database
- **WHEN** LLM analysis completes for the word "アリス" in folder "my_novel" with summary type "spoiler"
- **THEN** the summary text is saved to the `word_summaries` table with folder_name="my_novel", word="アリス", summary_type="spoiler", and current timestamps

#### Scenario: Save no-spoiler summary with source file
- **WHEN** LLM analysis completes for the word "アリス" in folder "my_novel" with summary type "no_spoiler" while viewing file "040_chapter.txt"
- **THEN** the summary is saved with source_file="040_chapter.txt" to track the reading position

### Requirement: Load cached summary on word selection
The system SHALL check the database for a cached summary when a word is selected, and display it immediately if found.

#### Scenario: Cache hit for previously analyzed word
- **WHEN** the user selects the word "アリス" which was previously analyzed in the current folder
- **THEN** the cached summary is loaded from the database and displayed without requiring LLM analysis

#### Scenario: Cache miss for new word
- **WHEN** the user selects a word that has not been analyzed in the current folder
- **THEN** no cached summary is found and the panel shows the empty state with the "解析開始" button

#### Scenario: Separate cache for spoiler and no-spoiler
- **WHEN** the user has previously analyzed "アリス" on the "ネタバレあり" tab
- **THEN** the "ネタバレあり" tab shows the cached result, while the "ネタバレなし" tab shows the empty state (each type is cached independently)

### Requirement: Update cache on re-analysis
The system SHALL update the existing cached summary when the user triggers re-analysis via the "解析開始" button.

#### Scenario: Re-analysis updates existing cache
- **WHEN** the user presses "解析開始" for a word that already has a cached summary
- **THEN** the new LLM result replaces the old cached summary and the `updated_at` timestamp is updated

### Requirement: No-spoiler cache position awareness
The system SHALL track the source file position for no-spoiler summaries and indicate when the cached result was generated from a different reading position.

#### Scenario: Cache from same position
- **WHEN** the user selects a word while viewing "040_chapter.txt" and a no-spoiler cache exists with source_file="040_chapter.txt"
- **THEN** the cached summary is displayed normally

#### Scenario: Cache from different position
- **WHEN** the user selects a word while viewing "060_chapter.txt" and a no-spoiler cache exists with source_file="040_chapter.txt"
- **THEN** the cached summary is displayed with a notice indicating it was generated at a different reading position, and the "解析開始" button is prominently available for re-analysis

### Requirement: Database schema migration for word summaries
The system SHALL add the `word_summaries` table via database migration from version 1 to version 2.

#### Scenario: Migrate from version 1 to version 2
- **WHEN** the application starts with an existing version 1 database
- **THEN** the `word_summaries` table is created via `onUpgrade` without affecting existing `novels` table data

#### Scenario: Fresh install creates both tables
- **WHEN** the application starts with no existing database
- **THEN** the `onCreate` handler creates both the `novels` table and the `word_summaries` table
