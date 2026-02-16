## MODIFIED Requirements

### Requirement: Prompt construction for word summary
The system SHALL construct LLM prompts using the multi-stage pipeline instead of a single prompt, removing the 10-entry context limit and processing all matched contexts through chunked fact extraction and aggregation.

#### Scenario: Build prompt via pipeline for many contexts
- **WHEN** the system builds a summary for the word "聖印" with 100 matching contexts found
- **THEN** the system passes all 100 contexts to the pipeline for chunked fact extraction and final summary generation, instead of limiting to 10 entries

#### Scenario: Build prompt via pipeline for few contexts
- **WHEN** the system builds a summary for the word "聖印" with 3 matching contexts found
- **THEN** the system passes all 3 contexts to the pipeline, which creates a single chunk and generates the summary in minimal stages

### Requirement: Spoiler summary uses all files
The "ネタバレあり" summary SHALL use search results from all text files in the document folder as context, passing them to the multi-stage pipeline.

#### Scenario: Generate spoiler summary from all files
- **WHEN** the user triggers analysis on the "ネタバレあり" tab for the word "アリス"
- **THEN** the system searches all text files in the current directory for "アリス", collects surrounding context from all matches, and passes them to the pipeline for chunked processing and summary generation

### Requirement: No-spoiler summary uses files up to current position
The "ネタバレなし" summary SHALL use search results only from text files up to and including the currently viewed file, based on numeric filename prefix ordering, passing them to the multi-stage pipeline.

#### Scenario: Generate no-spoiler summary limited to current file position
- **WHEN** the user is viewing file "040_chapter.txt" and triggers analysis on the "ネタバレなし" tab for the word "アリス"
- **THEN** the system searches only files with numeric prefix <= 40 and passes only those results to the pipeline for chunked processing and summary generation

#### Scenario: No-spoiler excludes later files
- **WHEN** the user is viewing file "040_chapter.txt" and files "050_chapter.txt" and "060_chapter.txt" also contain the search term
- **THEN** those later files are excluded from the contexts passed to the pipeline
