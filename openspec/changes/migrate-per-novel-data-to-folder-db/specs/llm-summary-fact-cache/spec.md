## MODIFIED Requirements

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

#### Scenario: Sentinel guarantees re-extraction

- **WHEN** the cache rows for word "アリス" in "novelA" have their `content_hash` set to the invalid sentinel value
- **THEN** the next analysis of "アリス" SHALL re-extract facts for every in-scope file and replace the sentinel rows with rows carrying the files' current content hashes

### Requirement: Cascade cleanup of cache rows

The system SHALL remove `fact_cache` rows whenever the corresponding summary data is deleted. Deleting all summaries for a word SHALL delete that word's cache rows in the same novel's `novel_data.db`. Deleting an entire novel SHALL remove its `fact_cache` together with the rest of `novel_data.db` by deleting the folder (no per-row global cascade is needed). No cache row SHALL be left orphaned after a deletion.

#### Scenario: Per-word deletion removes cache rows

- **WHEN** the user deletes all summaries for word "アリス" in "novelA"
- **THEN** every `fact_cache` row for `(アリス, *)` in "novelA"'s `novel_data.db` SHALL also be deleted

#### Scenario: Whole-novel deletion removes cache rows with the folder

- **WHEN** the novel "novelA" is deleted
- **THEN** its `fact_cache` rows SHALL cease to exist because "novelA"'s `novel_data.db` file is removed with the folder
- **AND** no orphaned `fact_cache` row SHALL remain in any database
