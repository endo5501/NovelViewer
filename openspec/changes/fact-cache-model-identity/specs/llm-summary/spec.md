## MODIFIED Requirements

### Requirement: Re-analysis forces fresh fact extraction

When the user re-analyzes a word at the same `covered_up_to_episode` as an existing snapshot (the "re-analyze to fix a bad result" action), the system SHALL force fresh Stage-1 extraction for that word by invalidating its fact-cache rows before running, so the re-analysis does not silently reuse the previously cached facts. Invalidation SHALL use the sentinel mechanism defined in `llm-summary-fact-cache`.

Invalidation SHALL be scoped to the model identity the run itself will use. The result the reader is discarding was produced by the model now configured, so that model's shelf is the state to throw away; rows belonging to other models are unrelated work the reader may still return to, and invalidating them would charge the whole cost of a model switch to an action that never asked for one.

Invalidation SHALL be scoped by the `updated_at` of the word's most recent snapshot at ANY `covered_up_to_episode`: only fact-cache rows whose `updated_at` is not newer than that mark SHALL be invalidated. Because only a run that saves a snapshot advances the mark, a row newer than it can only have been produced by an attempt that failed before saving; such rows are already fresh and SHALL be preserved. Without this scoping, every failed re-analysis attempt would discard the extraction work of the attempt before it, making each retry cost the full set of files instead of only the ones that failed.

The bound SHALL be the word's newest snapshot rather than the snapshot being replaced, because a later analysis at a wider scope can refresh a fact-cache row after the replaced snapshot was written. Bounding by the replaced snapshot alone would leave such a row valid and serve it from cache, defeating "redo from scratch" for exactly the file the user is re-analyzing to fix.

#### Scenario: Re-analysis re-extracts instead of reusing cache

- **WHEN** the user re-analyzes "アリス" at a `covered_up_to_episode` for which a snapshot already exists
- **THEN** the system SHALL invalidate the cache rows for that word under the configured model and re-extract facts for the in-scope files, rather than reusing the existing cached facts

#### Scenario: Re-analysis leaves another model's rows alone

- **WHEN** the user re-analyzes "アリス" with a client whose identity is M2, and cache rows for the word exist under both M1 and M2
- **THEN** the M2 rows SHALL be invalidated and the M1 rows SHALL keep their `content_hash` and `facts`

#### Scenario: Re-analysis after a model switch extracts everything anyway

- **WHEN** the user switches to a model that has never analyzed "アリス" and re-analyzes at a `covered_up_to_episode` for which a snapshot exists
- **THEN** the invalidation SHALL find no rows on that model's shelf, and every in-scope file SHALL be extracted fresh

#### Scenario: Re-analysis result overwrites the snapshot

- **WHEN** the re-analysis completes after forced extraction
- **THEN** the snapshot at that `covered_up_to_episode` SHALL be overwritten with the freshly generated summary, and the word's cache rows for the configured model SHALL hold the newly extracted facts with valid content hashes

#### Scenario: A retried re-analysis preserves the previous attempt's extractions

- **WHEN** a re-analysis of "アリス" re-extracted four of five files and failed on the fifth without saving a snapshot, and the user runs the same re-analysis again
- **THEN** the four rows written by the failed attempt SHALL NOT be invalidated, and the system SHALL issue extraction calls only for the file that previously failed

#### Scenario: A row refreshed by a later wider analysis is still re-extracted

- **WHEN** "アリス" has a snapshot at episode 3, a subsequent analysis at episode 6 re-extracted `002_ch.txt` (its content had changed) and saved its own snapshot, and the user then re-analyzes at episode 3
- **THEN** the row for `002_ch.txt` SHALL be invalidated despite being newer than the episode-3 snapshot, and every in-scope file SHALL be re-extracted
