## Purpose

Persist and reuse per-file Stage-1 fact-extraction results so that incremental word/phrase analyses avoid re-extracting facts from source files that have not changed. The cache is keyed per source file, validated by content hash and prompt version, force-invalidated via a sentinel, and cleaned up in cascade when the corresponding summary data is deleted.
## Requirements
### Requirement: Per-file fact cache storage

The system SHALL persist the Stage-1 fact-extraction result for each analyzed source file in a `fact_cache` table keyed by `(folder_name, word, file_name)`. Each row SHALL store the extracted `facts` text, a `content_hash` of the source file, a `prompt_version` identifying the extraction-prompt format used, and an `updated_at` timestamp. Re-extracting an already-cached `(folder_name, word, file_name)` SHALL upsert the row in place.

#### Scenario: Extraction result is cached per file

- **WHEN** Stage-1 fact extraction completes for word "アリス" against file "005_ch.txt" in folder "novelA"
- **THEN** a `fact_cache` row SHALL exist for `(novelA, アリス, 005_ch.txt)` containing the extracted facts, the file's content hash, and the current prompt version

#### Scenario: Re-extraction upserts in place

- **WHEN** a `fact_cache` row already exists for `(novelA, アリス, 005_ch.txt)` and that file is extracted again
- **THEN** the existing row SHALL be updated (not duplicated), so at most one row exists per `(folder_name, word, file_name)`

### Requirement: Cache validity check

Before extracting facts for an in-scope file, the system SHALL consult the `fact_cache`. The cached facts SHALL be reused only when a row exists for `(folder_name, word, file_name)` AND its stored `content_hash` equals a hash of the file's current full content AND its stored `prompt_version` equals the current extraction-prompt version. On any mismatch (missing row, differing hash, or differing prompt version) the system SHALL treat the file as a cache miss, extract facts fresh, and overwrite the cache row.

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

The system SHALL support forcing a cache miss for a `(folder_name, word)` by writing the invalid sentinel `content_hash` value — the empty string — to its rows. A row whose `content_hash` is the empty string SHALL never satisfy the validity check, so the next analysis re-extracts the affected files and overwrites the rows with a valid hash.

#### Scenario: Sentinel guarantees re-extraction

- **WHEN** the cache rows for `(novelA, アリス)` have their `content_hash` set to the invalid sentinel value
- **THEN** the next analysis of "アリス" SHALL re-extract facts for every in-scope file and replace the sentinel rows with rows carrying the files' current content hashes

### Requirement: Cascade cleanup of cache rows

The system SHALL remove `fact_cache` rows whenever the corresponding summary data is deleted. Deleting all summaries for a word SHALL delete that word's cache rows in the same folder; deleting all summaries for a folder SHALL delete every cache row for that folder. No cache row SHALL be left orphaned after a deletion.

#### Scenario: Per-word deletion removes cache rows

- **WHEN** the user deletes all summaries for `(novelA, アリス)`
- **THEN** every `fact_cache` row for `(novelA, アリス, *)` SHALL also be deleted

#### Scenario: Per-folder deletion removes cache rows

- **WHEN** all summary data for folder "novelA" is deleted
- **THEN** every `fact_cache` row for folder "novelA" SHALL also be deleted
