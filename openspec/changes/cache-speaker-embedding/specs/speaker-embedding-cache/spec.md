## ADDED Requirements

### Requirement: Embedding cache directory management
The system SHALL manage an embedding cache directory at `{LibraryParentDir}/cache/embeddings/` for storing pre-computed speaker embeddings. The system SHALL automatically create the directory if it does not exist when the cache is first accessed.

#### Scenario: Cache directory auto-creation
- **WHEN** the embedding cache is accessed for the first time and the `cache/embeddings/` directory does not exist
- **THEN** the system creates the directory automatically

#### Scenario: Cache directory already exists
- **WHEN** the embedding cache is accessed and the `cache/embeddings/` directory already exists
- **THEN** the system uses the existing directory without modification

### Requirement: Automatic embedding caching by file content hash
The system SHALL automatically cache speaker embeddings using the SHA256 hash of the reference audio file content as the cache key. The cache file SHALL be stored at `{LibraryParentDir}/cache/embeddings/{sha256_hex}.emb` in raw binary format (float32 array, 4096 bytes for 1024 dimensions).

#### Scenario: Cache miss — first use of a reference audio file
- **WHEN** `synthesizeWithVoice` is called with a reference audio file whose SHA256 hash does not match any existing cache file
- **THEN** the system extracts the speaker embedding via the C API, saves it to `cache/embeddings/{sha256_hex}.emb`, and uses it for synthesis

#### Scenario: Cache hit — reuse of a previously used reference audio file
- **WHEN** `synthesizeWithVoice` is called with a reference audio file whose SHA256 hash matches an existing cache file
- **THEN** the system loads the cached embedding from disk and uses `synthesize_with_embedding` for synthesis, skipping the encoder entirely

#### Scenario: Reference audio file content changed
- **WHEN** a reference audio file at the same path has been replaced with different content
- **THEN** the SHA256 hash differs from the previous cache key, causing a cache miss and a new embedding extraction

#### Scenario: Cache file is corrupted or invalid size
- **WHEN** a cached embedding file exists but has an unexpected size (not 4096 bytes)
- **THEN** the system discards the invalid cache file, re-extracts the embedding, and saves a new cache file

### Requirement: Transparent caching in TTS synthesis flow
The caching mechanism SHALL be transparent to the caller. The existing `synthesizeWithVoice(text, refWavPath)` interface SHALL remain unchanged. The caching logic SHALL be internal to the TTS engine layer.

#### Scenario: Caller interface unchanged
- **WHEN** a caller invokes `synthesizeWithVoice(text, refWavPath)` with a reference audio path
- **THEN** the synthesis completes successfully regardless of cache state, with identical audio quality whether the embedding was cached or freshly extracted

#### Scenario: Synthesis without reference audio is unaffected
- **WHEN** `synthesize(text)` is called without a reference audio path
- **THEN** the caching mechanism is not involved and synthesis proceeds as before
