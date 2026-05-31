## MODIFIED Requirements

### Requirement: Prompt construction for word summary

The system SHALL construct LLM prompts using the multi-stage pipeline instead of a single prompt, removing the 10-entry context limit and processing all matched contexts through fact extraction and aggregation. The contexts SHALL be pre-filtered by the analysis trigger's snapshot upper bound (see "Snapshot-based analysis scope"). Stage-1 fact extraction SHALL be assembled from the per-file fact cache: for each in-scope source file the system SHALL reuse the file's valid cached facts when present (see `llm-summary-fact-cache`) and SHALL extract facts only for files that are a cache miss. The assembled facts (cached plus freshly extracted) SHALL then be aggregated and summarized by the pipeline as before. The cache lookup SHALL NOT change the analysis result relative to extracting every in-scope file fresh.

#### Scenario: Build summary reusing cached facts for prior episodes

- **WHEN** the system builds a summary for "聖印" over files 1–7, and files 1–5 already have valid cache rows while files 6–7 do not
- **THEN** the system reuses the cached facts for files 1–5, extracts facts only for files 6–7, and aggregates the combined facts into the final summary

#### Scenario: Build summary with a cold cache

- **WHEN** the system builds a summary for "聖印" over files 1–7 and no cache rows exist
- **THEN** the system extracts facts for all of files 1–7, aggregates them into the final summary, and the result matches the pre-cache behavior

#### Scenario: Build summary for few contexts

- **WHEN** the system builds a summary for "聖印" with only 3 matching contexts in a single file and no valid cache row
- **THEN** the system extracts that file's facts and generates the summary in minimal stages

## ADDED Requirements

### Requirement: Re-analysis forces fresh fact extraction

When the user re-analyzes a word at the same `covered_up_to_episode` as an existing snapshot (the "re-analyze to fix a bad result" action), the system SHALL force fresh Stage-1 extraction for that word by invalidating its fact-cache rows before running, so the re-analysis does not silently reuse the previously cached facts. Invalidation SHALL use the sentinel mechanism defined in `llm-summary-fact-cache`.

#### Scenario: Re-analysis re-extracts instead of reusing cache

- **WHEN** the user re-analyzes "アリス" at a `covered_up_to_episode` for which a snapshot already exists
- **THEN** the system SHALL invalidate the cache rows for that word and re-extract facts for the in-scope files, rather than reusing the existing cached facts

#### Scenario: Re-analysis result overwrites the snapshot

- **WHEN** the re-analysis completes after forced extraction
- **THEN** the snapshot at that `covered_up_to_episode` SHALL be overwritten with the freshly generated summary, and the word's cache rows SHALL hold the newly extracted facts with valid content hashes
