## Purpose

Persist and reuse per-file Stage-1 fact-extraction results so that incremental word/phrase analyses avoid re-extracting facts from source files that have not changed. The cache is keyed per source file, validated by content hash and prompt version, force-invalidated via a sentinel, and cleaned up in cascade when the corresponding summary data is deleted.
## Requirements
### Requirement: Per-file fact cache storage

The system SHALL persist the Stage-1 fact-extraction result for each analyzed source file in a `fact_cache` table **inside the per-folder `novel_data.db` of the analyzed novel**, keyed by `(word, file_name)`. The table SHALL NOT carry a `folder_name` column; the novel identity is conveyed by which folder's `novel_data.db` the row lives in. Each row SHALL store the extracted `facts` text, a `content_hash` of the source file, a `prompt_version` identifying the extraction-prompt format used, and an `updated_at` timestamp. Re-extracting an already-cached `(word, file_name)` SHALL upsert the row in place.

#### Scenario: Extraction result is cached per file

- **WHEN** Stage-1 fact extraction completes for word "アリス" against file "005_ch.txt" in folder "novelA"
- **THEN** a `fact_cache` row SHALL exist in "novelA"'s `novel_data.db` for `(アリス, 005_ch.txt)` containing the extracted facts, the file's content hash, and the current prompt version

#### Scenario: Re-extraction upserts in place

- **WHEN** a `fact_cache` row already exists for `(アリス, 005_ch.txt)` in the folder's `novel_data.db` and that file is extracted again
- **THEN** the existing row SHALL be updated (not duplicated), so at most one row exists per `(word, file_name)`

### Requirement: Cache validity check

Before extracting facts for an in-scope file, the system SHALL consult the active novel's `fact_cache`. The cached facts SHALL be reused only when a row exists for `(word, file_name)` AND its stored `content_hash` equals a hash of the file's current full content AND its stored `prompt_version` equals the current extraction-prompt version. On any mismatch (missing row, differing hash, or differing prompt version) the system SHALL treat the file as a cache miss, extract facts fresh, and overwrite the cache row.

#### Scenario: Valid cache row is reused without an LLM call

- **WHEN** analyzing "アリス" over a scope that includes "005_ch.txt", and the cache row for that file has a matching content hash and prompt version
- **THEN** the system SHALL reuse the cached facts for that file and SHALL NOT issue a Stage-1 LLM call for it

#### Scenario: Changed source content invalidates the file

- **WHEN** "005_ch.txt" has been edited since it was cached, so its current content hash differs from the stored hash
- **THEN** the system SHALL re-extract facts for that file and overwrite its cache row, even though a row exists

#### Scenario: Prompt-version change invalidates the file

- **WHEN** the current extraction-prompt version differs from a cache row's stored `prompt_version`
- **THEN** the system SHALL treat that file as a cache miss and re-extract it, regardless of whether the content hash matches

### Requirement: Sentinel-based forced invalidation

The system SHALL support forcing a cache miss for a `word` by writing the invalid sentinel `content_hash` value — the empty string — to its rows in the active novel's `fact_cache`. A row whose `content_hash` is the empty string SHALL never satisfy the validity check, so the next analysis re-extracts the affected files and overwrites the rows with a valid hash.

Forced invalidation SHALL accept a reference timestamp and SHALL apply the sentinel only to rows whose `updated_at` is not newer than that timestamp. Rows updated strictly after the reference timestamp SHALL be left untouched, because they were produced after the state the invalidation is meant to discard. Invoking forced invalidation without a reference timestamp SHALL invalidate every row for the word, as before.

#### Scenario: Sentinel guarantees re-extraction

- **WHEN** the cache rows for word "アリス" in "novelA" have their `content_hash` set to the invalid sentinel value
- **THEN** the next analysis of "アリス" SHALL re-extract facts for every in-scope file and replace the sentinel rows with rows carrying the files' current content hashes

#### Scenario: Rows newer than the reference timestamp are preserved

- **WHEN** forced invalidation for word "アリス" is invoked with a reference timestamp, and one of the word's rows has an `updated_at` strictly later than it while the others are earlier
- **THEN** the earlier rows SHALL receive the sentinel `content_hash` and the later row SHALL keep its existing `content_hash` and `facts`

#### Scenario: Rows at exactly the reference timestamp are invalidated

- **WHEN** forced invalidation for word "アリス" is invoked with a reference timestamp equal to a row's `updated_at`
- **THEN** that row SHALL receive the sentinel `content_hash`

### Requirement: Cascade cleanup of cache rows

The system SHALL remove `fact_cache` rows whenever the corresponding summary data is deleted. Deleting all summaries for a word SHALL delete that word's cache rows in the same novel's `novel_data.db`. Deleting an entire novel SHALL remove its `fact_cache` together with the rest of `novel_data.db` by deleting the folder (no per-row global cascade is needed). No cache row SHALL be left orphaned after a deletion.

#### Scenario: Per-word deletion removes cache rows

- **WHEN** the user deletes all summaries for word "アリス" in "novelA"
- **THEN** every `fact_cache` row for `(アリス, *)` in "novelA"'s `novel_data.db` SHALL also be deleted

#### Scenario: Whole-novel deletion removes cache rows with the folder

- **WHEN** the novel "novelA" is deleted
- **THEN** its `fact_cache` rows SHALL cease to exist because "novelA"'s `novel_data.db` file is removed with the folder
- **AND** no orphaned `fact_cache` row SHALL remain in any database

### Requirement: Only structurally parsed, non-empty facts are cached

The system SHALL write a `fact_cache` row for a source file only when that file's Stage-1 result was obtained from a successful structured decode of every LLM response involved and is not empty after trimming. Facts obtained via the raw-text fallback (the response failed `jsonDecode`), and facts that are empty, SHALL NOT be persisted. A file whose result is withheld SHALL be treated as a cache miss by the next analysis, so it is re-extracted rather than serving a degraded value.

This prevents fragments of malformed JSON (e.g. `{"facts": "- ...`) and empty responses from entering the cache and contaminating every later analysis of that word until the prompt version changes.

#### Scenario: A raw-text fallback result is not cached

- **WHEN** Stage-1 extraction for file "005_ch.txt" produced its value through the raw-text fallback because the response failed `jsonDecode`
- **THEN** no `fact_cache` row SHALL be written or updated for that file, and the next analysis SHALL treat it as a cache miss

#### Scenario: An empty facts result is not cached

- **WHEN** Stage-1 extraction for file "005_ch.txt" returned a structurally valid response whose facts value is empty after trimming
- **THEN** no `fact_cache` row SHALL be written or updated for that file

#### Scenario: A structurally parsed, non-empty result is cached

- **WHEN** Stage-1 extraction for file "005_ch.txt" returned a structurally valid response with non-empty facts
- **THEN** the `fact_cache` row for that file SHALL be upserted with the facts, the file's current content hash, and the current prompt version

