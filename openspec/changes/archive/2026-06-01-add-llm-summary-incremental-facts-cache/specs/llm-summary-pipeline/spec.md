## MODIFIED Requirements

### Requirement: Chunk splitting by character count

The system SHALL perform Stage-1 fact extraction at source-file granularity: the context entries belonging to a single source file form an independent extraction unit, and context entries from different source files SHALL NOT be packed into the same chunk. Within a single file's extraction unit, the system SHALL split that file's own context entries into chunks of approximately 4000 characters each, without splitting an individual context entry across chunk boundaries, and combine the per-chunk results into that file's facts.

#### Scenario: Each file is an independent extraction unit

- **WHEN** the in-scope context entries come from three source files
- **THEN** the system SHALL produce one fact-extraction unit per file, and SHALL NOT combine entries from different files into a shared chunk

#### Scenario: Single chunk when a file's contexts are small

- **WHEN** a single file's context entries total 3000 characters
- **THEN** the system creates a single chunk for that file containing all of its context entries

#### Scenario: A file with large contexts is chunked internally

- **WHEN** a single file's context entries total 12000 characters
- **THEN** the system splits that file's entries into approximately 4000-character chunks (about 3 chunks), keeps each context entry intact within a chunk, and combines the chunk results into that file's facts

#### Scenario: Large individual context entry

- **WHEN** a single context entry within a file exceeds 4000 characters
- **THEN** the context entry is placed in its own chunk without being split
