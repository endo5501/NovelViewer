## ADDED Requirements

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

## MODIFIED Requirements

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
