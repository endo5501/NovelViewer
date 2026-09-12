## Purpose

Persist and reuse per-file Stage-1 fact-extraction results so that incremental word/phrase analyses avoid re-extracting facts from source files that have not changed. The cache is keyed per source file, validated by content hash and prompt version, force-invalidated via a sentinel, and cleaned up in cascade when the corresponding summary data is deleted.
## Requirements

### Requirement: Per-file fact cache storage

The system SHALL persist the Stage-1 fact-extraction result for each analyzed source file in a `fact_cache` table **inside the per-folder `novel_data.db` of the analyzed novel**, keyed by `(word, file_name, model_id)`. The table SHALL NOT carry a `folder_name` column; the novel identity is conveyed by which folder's `novel_data.db` the row lives in. Each row SHALL store the extracted `facts` text, a `content_hash` of the source file, a `prompt_version` identifying the extraction-prompt format used, the `model_id` of the model that produced the facts, and an `updated_at` timestamp. Re-extracting an already-cached `(word, file_name, model_id)` SHALL upsert the row in place.

The model identity belongs in the key rather than only in the validity check. Each model therefore keeps its own shelf, and a reader who moves between an on-device model and a server model finds the earlier extractions still there on returning, instead of paying for every file again in both directions. Because one analysis run reads and writes a single shelf, a run's evidence SHALL be homogeneous in provenance by construction rather than by care.

#### Scenario: Extraction result is cached per file and per model

- **WHEN** Stage-1 fact extraction completes for word "アリス" against file "005_ch.txt" in folder "novelA", run by a client whose model identity is M
- **THEN** a `fact_cache` row SHALL exist in "novelA"'s `novel_data.db` for `(アリス, 005_ch.txt, M)` containing the extracted facts, the file's content hash, and the current prompt version

#### Scenario: Re-extraction upserts in place

- **WHEN** a `fact_cache` row already exists for `(アリス, 005_ch.txt, M)` in the folder's `novel_data.db` and that file is extracted again by the same model
- **THEN** the existing row SHALL be updated (not duplicated), so at most one row exists per `(word, file_name, model_id)`

#### Scenario: Two models keep separate rows for the same file

- **WHEN** file "005_ch.txt" is extracted for word "アリス" first by a model whose identity is M1 and later by one whose identity is M2
- **THEN** both rows SHALL exist side by side, each carrying its own facts, and neither SHALL have overwritten the other

### Requirement: Cache validity check

Before extracting facts for an in-scope file, the system SHALL consult the active novel's `fact_cache` for the identity of the model that will do the extracting. The cached facts SHALL be reused only when a row exists for `(word, file_name, model_id)` AND its stored `content_hash` equals a hash of the file's current full content AND its stored `prompt_version` equals the current extraction-prompt version. On any mismatch (missing row, differing hash, or differing prompt version) the system SHALL treat the file as a cache miss, extract facts fresh, and overwrite the cache row for that model.

A row belonging to a different model SHALL NOT be consulted at all. It is not a miss to be reported but a row on another shelf, and reading it would put facts from one model into a run attributed to another.

#### Scenario: Valid cache row is reused without an LLM call

- **WHEN** analyzing "アリス" with a client whose identity is M over a scope that includes "005_ch.txt", and the row for `(アリス, 005_ch.txt, M)` has a matching content hash and prompt version
- **THEN** the system SHALL reuse the cached facts for that file and SHALL NOT issue a Stage-1 LLM call for it

#### Scenario: Another model's row is not reused

- **WHEN** analyzing "アリス" with a client whose identity is M2, and the only row for "005_ch.txt" was written by M1 with a matching content hash and prompt version
- **THEN** the system SHALL treat the file as a cache miss, extract it with M2, and write a row for `(アリス, 005_ch.txt, M2)`
- **AND** the M1 row SHALL be left untouched

#### Scenario: A run's evidence comes from a single model

- **WHEN** an analysis of "アリス" runs with a client whose identity is M over files some of which were last extracted by another model
- **THEN** every fact the run assembles SHALL come from a row whose `model_id` is M, whether reused or written by this run

#### Scenario: Changed source content invalidates the file

- **WHEN** "005_ch.txt" has been edited since it was cached, so its current content hash differs from the hash stored on the current model's row
- **THEN** the system SHALL re-extract facts for that file and overwrite that row, even though a row exists

#### Scenario: Prompt-version change invalidates the file

- **WHEN** the current extraction-prompt version differs from the `prompt_version` on the current model's row
- **THEN** the system SHALL treat that file as a cache miss and re-extract it, regardless of whether the content hash matches

### Requirement: Sentinel-based forced invalidation

The system SHALL support forcing a cache miss for a `word` under one model by writing the invalid sentinel `content_hash` value — the empty string — to that model's rows for the word in the active novel's `fact_cache`. A row whose `content_hash` is the empty string SHALL never satisfy the validity check, so the next analysis with that model re-extracts the affected files and overwrites the rows with a valid hash.

Forced invalidation SHALL be scoped to a single model identity. Rows belonging to other models SHALL be left untouched, because the state being discarded was produced by one model and the other shelves hold unrelated work that the reader may still return to.

Forced invalidation SHALL accept a reference timestamp and SHALL apply the sentinel only to rows whose `updated_at` is not newer than that timestamp. Rows updated strictly after the reference timestamp SHALL be left untouched, because they were produced after the state the invalidation is meant to discard. Invoking forced invalidation without a reference timestamp SHALL invalidate every row for the word under that model.

#### Scenario: Sentinel guarantees re-extraction

- **WHEN** the cache rows for word "アリス" under model M in "novelA" have their `content_hash` set to the invalid sentinel value
- **THEN** the next analysis of "アリス" with model M SHALL re-extract facts for every in-scope file and replace the sentinel rows with rows carrying the files' current content hashes

#### Scenario: Another model's rows survive invalidation

- **WHEN** forced invalidation for word "アリス" is invoked for model M1, and rows for the word exist under both M1 and M2
- **THEN** the M1 rows SHALL receive the sentinel `content_hash` and the M2 rows SHALL keep their existing `content_hash` and `facts`

#### Scenario: Rows newer than the reference timestamp are preserved

- **WHEN** forced invalidation for word "アリス" under model M is invoked with a reference timestamp, and one of that model's rows has an `updated_at` strictly later than it while the others are earlier
- **THEN** the earlier rows SHALL receive the sentinel `content_hash` and the later row SHALL keep its existing `content_hash` and `facts`

#### Scenario: Rows at exactly the reference timestamp are invalidated

- **WHEN** forced invalidation for word "アリス" under model M is invoked with a reference timestamp equal to a row's `updated_at`
- **THEN** that row SHALL receive the sentinel `content_hash`

### Requirement: Cascade cleanup of cache rows

The system SHALL remove `fact_cache` rows whenever the corresponding summary data is deleted. Deleting all summaries for a word SHALL delete that word's cache rows in the same novel's `novel_data.db`, under every model identity — the summaries being deleted were the reason to keep any of them. Deleting an entire novel SHALL remove its `fact_cache` together with the rest of `novel_data.db` by deleting the folder (no per-row global cascade is needed). No cache row SHALL be left orphaned after a deletion.

#### Scenario: Per-word deletion removes cache rows for every model

- **WHEN** the user deletes all summaries for word "アリス" in "novelA" and cache rows for that word exist under two different model identities
- **THEN** every `fact_cache` row for `(アリス, *, *)` in "novelA"'s `novel_data.db` SHALL also be deleted

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

### Requirement: The LLM client declares which model stands behind it

Every LLM client SHALL declare a model identity: a non-empty string naming the model that answers its requests. The identity SHALL be a property of the client rather than something the caller derives, for the same reason the context budget is: what model answers is a fact about the client, and only the client holds the provider and model name together.

There SHALL be no default identity. A default would let two different models share one identity and therefore one cache shelf, which is the exact failure this capability exists to prevent, and it would fail silently. A client that does not declare an identity SHALL fail to compile rather than fall back to a placeholder.

The identity SHALL be formed from the provider and the model name, and SHALL NOT include the endpoint address. The address says where a model is reached, not what it is; the same model name served from two hosts is the same model, and a reader's self-hosted server changing address SHALL NOT create a second shelf.

The identity SHALL be treated as opaque: stored as written, compared only for equality, and never parsed. A model name that itself contains the separator SHALL therefore be carried without special handling.

#### Scenario: Each client names its provider and model

- **WHEN** the model identity is read from a client configured for a server provider with model "qwen3:30b"
- **THEN** it SHALL be a non-empty string naming both the provider and "qwen3:30b"

#### Scenario: The on-device client names itself

- **WHEN** the model identity is read from the on-device client
- **THEN** it SHALL be a non-empty string naming the on-device model, carrying no endpoint and no configurable model name

#### Scenario: The endpoint address does not change the identity

- **WHEN** two clients are configured for the same provider and the same model name but different endpoint addresses
- **THEN** their model identities SHALL be equal

#### Scenario: Two models are never confused

- **WHEN** two clients are configured for the same provider with different model names
- **THEN** their model identities SHALL differ

### Requirement: A cache row without a model identity does not exist

Every `fact_cache` row SHALL carry a non-empty `model_id`. A row whose provenance is unknown SHALL NOT be created, and SHALL NOT be retained where one already exists.

This follows from the identity being part of the key. A row carrying an empty identity could never be found by any client, because no client declares an empty identity, and could never be replaced by an upsert, because the upsert would collide on a different key and insert alongside it. Such a row is not a cache entry but residue that accumulates forever and surfaces in the read-only inspector as an indistinguishable duplicate of a file name.

The storage SHALL enforce this rather than relying on the client contract alone: the `model_id` column SHALL reject an empty value as well as a null one. That the clients never produce an empty identity is a property of the clients; that no such row exists is a property of the table, and belongs where the rows live.

Rows that predate the model identity SHALL therefore be discarded when the identity is introduced, rather than retained under a placeholder. What the reader loses is one round of re-extraction for each word they analyze next, which is exactly what a `prompt_version` bump already costs and which the design treats as a normal event. Saved summaries SHALL NOT be affected.

#### Scenario: No row carries an empty identity

- **WHEN** the `fact_cache` table of any novel is inspected after the identity has been introduced
- **THEN** no row SHALL have an empty `model_id`

#### Scenario: The storage refuses an empty identity

- **WHEN** a `fact_cache` row is written with an empty `model_id`
- **THEN** the write SHALL fail and no row SHALL be stored

#### Scenario: Discarded rows do not affect saved summaries

- **WHEN** rows predating the model identity are discarded
- **THEN** the `word_summaries` rows built from those facts SHALL remain unchanged
