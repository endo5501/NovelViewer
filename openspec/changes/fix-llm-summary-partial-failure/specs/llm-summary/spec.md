## MODIFIED Requirements

### Requirement: Re-analysis forces fresh fact extraction

When the user re-analyzes a word at the same `covered_up_to_episode` as an existing snapshot (the "re-analyze to fix a bad result" action), the system SHALL force fresh Stage-1 extraction for that word by invalidating its fact-cache rows before running, so the re-analysis does not silently reuse the previously cached facts. Invalidation SHALL use the sentinel mechanism defined in `llm-summary-fact-cache`.

Invalidation SHALL be scoped by the existing snapshot's `updated_at`: only fact-cache rows whose `updated_at` is not newer than that snapshot SHALL be invalidated. Rows updated after the snapshot were produced by an earlier re-analysis attempt that failed before saving, and SHALL be preserved. Without this scoping, every failed re-analysis attempt would discard the extraction work of the attempt before it, making each retry cost the full set of files instead of only the ones that failed.

#### Scenario: Re-analysis re-extracts instead of reusing cache

- **WHEN** the user re-analyzes "アリス" at a `covered_up_to_episode` for which a snapshot already exists
- **THEN** the system SHALL invalidate the cache rows for that word and re-extract facts for the in-scope files, rather than reusing the existing cached facts

#### Scenario: Re-analysis result overwrites the snapshot

- **WHEN** the re-analysis completes after forced extraction
- **THEN** the snapshot at that `covered_up_to_episode` SHALL be overwritten with the freshly generated summary, and the word's cache rows SHALL hold the newly extracted facts with valid content hashes

#### Scenario: A retried re-analysis preserves the previous attempt's extractions

- **WHEN** a re-analysis of "アリス" re-extracted four of five files and failed on the fifth without saving a snapshot, and the user runs the same re-analysis again
- **THEN** the four rows written by the failed attempt SHALL NOT be invalidated, and the system SHALL issue extraction calls only for the file that previously failed
