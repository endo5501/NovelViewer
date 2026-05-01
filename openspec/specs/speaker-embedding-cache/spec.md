## Purpose

Cache extracted speaker embeddings (per-model, keyed by SHA256 of reference audio content) on disk to skip the encoder on repeat synthesis. Caching is transparent to callers of `synthesizeWithVoice`, with auto-creation of cache dirs and recovery from corrupted entries.

## Requirements

### Requirement: Embedding cache directory management
The system SHALL manage an embedding cache directory at `{LibraryParentDir}/cache/embeddings/{modelBasename}/` for storing pre-computed speaker embeddings, where `{modelBasename}` is the base name of the model directory (e.g., `0.6b`, `1.7b`). This per-model separation prevents cross-model cache contamination when different models produce different embedding dimensions. The system SHALL automatically create the directory if it does not exist when the cache is first accessed.

#### Scenario: Cache directory auto-creation
- **WHEN** the embedding cache is accessed for the first time and the `cache/embeddings/` directory does not exist
- **THEN** the system creates the directory automatically

#### Scenario: Cache directory already exists
- **WHEN** the embedding cache is accessed and the `cache/embeddings/` directory already exists
- **THEN** the system uses the existing directory without modification

### Requirement: Automatic embedding caching by file content hash
The system SHALL automatically cache speaker embeddings using the SHA256 hash of the reference audio file content as the cache key. The cache file SHALL be stored at `{LibraryParentDir}/cache/embeddings/{modelBasename}/{sha256_hex}.emb` in raw binary format (float32 array). The embedding size depends on the model's `hidden_size` (e.g., 1024 floats for 0.6B, 2048 floats for 1.7B).

#### Scenario: Cache miss — first use of a reference audio file
- **WHEN** `synthesizeWithVoice` is called with a reference audio file whose SHA256 hash does not match any existing cache file
- **THEN** the system extracts the speaker embedding via the C API, saves it to `cache/embeddings/{modelBasename}/{sha256_hex}.emb`, and uses it for synthesis

#### Scenario: Cache hit — reuse of a previously used reference audio file
- **WHEN** `synthesizeWithVoice` is called with a reference audio file whose SHA256 hash matches an existing cache file
- **THEN** the system loads the cached embedding from disk and uses `synthesize_with_embedding` for synthesis, skipping the encoder entirely

#### Scenario: Reference audio file content changed
- **WHEN** a reference audio file at the same path has been replaced with different content
- **THEN** the SHA256 hash differs from the previous cache key, causing a cache miss and a new embedding extraction

#### Scenario: Cache file is corrupted or invalid
- **WHEN** a cached embedding file exists but loading or synthesis with it fails (e.g., corrupted data, size mismatch after model change)
- **THEN** the system discards the invalid cache file, re-extracts the embedding, and saves a new cache file

### Requirement: Transparent caching in TTS synthesis flow
The caching mechanism SHALL be transparent to the caller. The existing `synthesizeWithVoice(text, refWavPath)` interface SHALL remain unchanged. The caching logic SHALL be internal to the TTS engine layer.

#### Scenario: Caller interface unchanged
- **WHEN** a caller invokes `synthesizeWithVoice(text, refWavPath)` with a reference audio path
- **THEN** the synthesis completes successfully regardless of cache state, with identical audio quality whether the embedding was cached or freshly extracted

#### Scenario: Synthesis without reference audio is unaffected
- **WHEN** `synthesize(text)` is called without a reference audio path
- **THEN** the caching mechanism is not involved and synthesis proceeds as before
