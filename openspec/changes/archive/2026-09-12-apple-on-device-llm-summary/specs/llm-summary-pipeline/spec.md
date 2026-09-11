## MODIFIED Requirements

### Requirement: Chunk splitting by character count

The system SHALL perform Stage-1 fact extraction at source-file granularity: the context entries belonging to a single source file form an independent extraction unit, and context entries from different source files SHALL NOT be packed into the same chunk. Within a single file's extraction unit, the system SHALL split that file's own context entries into chunks of approximately the LLM client's declared context budget in characters, without splitting an individual context entry across chunk boundaries, and combine the per-chunk results into that file's facts.

The context budget SHALL be a property of the LLM client rather than a constant of the pipeline, and the service that assembles the pipeline SHALL read it from the client it was given. How much text a model can be handed at once is a property of the model, and a client whose model runs on the device has a far smaller window than one that reaches a server. A client that does not declare a budget SHALL be treated as declaring 4000 characters, which is the value every client used before the budget was introduced.

The budget SHALL be an upper bound on what any chunk carries, including where a single context entry exceeds it on its own. A context entry is otherwise kept whole, because it is the passage around a match and cutting it costs the model the run-up to what it is being asked about. An entry larger than the entire budget cannot be kept whole without handing the model more than it accepts, which on a small window fails the request outright; a novel written in long paragraphs produces such entries. Such an entry SHALL therefore be broken into pieces that each fit, preferring a line break where one falls within the budget, and no character SHALL be lost.

#### Scenario: Each file is an independent extraction unit

- **WHEN** the in-scope context entries come from three source files
- **THEN** the system SHALL produce one fact-extraction unit per file, and SHALL NOT combine entries from different files into a shared chunk

#### Scenario: Single chunk when a file's contexts are small

- **WHEN** a single file's context entries total 3000 characters and the client's budget is 4000 characters
- **THEN** the system creates a single chunk for that file containing all of its context entries

#### Scenario: A file with large contexts is chunked internally

- **WHEN** a single file's context entries total 12000 characters and the client's budget is 4000 characters
- **THEN** the system splits that file's entries into approximately 4000-character chunks (about 3 chunks), keeps each context entry intact within a chunk, and combines the chunk results into that file's facts

#### Scenario: An entry larger than the whole budget is broken up

- **WHEN** a single context entry within a file exceeds the client's budget on its own
- **THEN** the entry SHALL be broken into pieces that each fit the budget, preferring a line break where the cut allows one
- **AND** no character of the entry SHALL be lost

#### Scenario: A smaller budget produces more chunks

- **WHEN** a single file's context entries total 12000 characters and the client declares a budget of 2000 characters
- **THEN** the system splits that file's entries into approximately 2000-character chunks, producing about twice as many chunks as it would at 4000

#### Scenario: A client that declares no budget keeps the previous behaviour

- **WHEN** the pipeline is assembled from a client that declares no context budget
- **THEN** chunking SHALL behave exactly as it did at a fixed 4000 characters

### Requirement: Recursive fact aggregation
The system SHALL recursively aggregate extracted facts when the combined facts exceed the client's declared context budget, re-chunking and re-extracting until the total fits within that budget. The same budget governs both Stage-1 chunking and this aggregation, so a client's window is respected wherever text is handed to the model.

#### Scenario: Facts fit within limit after first extraction
- **WHEN** Stage 1 produces a combined facts text of 2000 characters and the client's budget is 4000 characters
- **THEN** the system proceeds directly to the final summary stage without further recursion

#### Scenario: Facts exceed limit requiring re-aggregation
- **WHEN** Stage 1 produces a combined facts text of 8000 characters and the client's budget is 4000 characters
- **THEN** the system splits the facts into chunks of approximately 4000 characters each, sends each chunk to the LLM for further fact aggregation, and repeats until the total is within 4000 characters

#### Scenario: A smaller budget lowers the aggregation threshold
- **WHEN** Stage 1 produces a combined facts text of 3000 characters and the client declares a budget of 2000 characters
- **THEN** the system SHALL enter recursive aggregation rather than proceeding directly to the final summary stage

#### Scenario: Recursion limit reached
- **WHEN** fact aggregation has been performed 5 times and the total still exceeds the client's budget
- **THEN** the system stops recursion and proceeds to the final summary stage with the current facts
