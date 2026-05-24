## Purpose

Summarize a Web novel character/keyword's appearances by chunking long-context evidence and recursively distilling facts before producing a final summary.
## Requirements
### Requirement: Chunk splitting by character count
The system SHALL split collected context entries into chunks of approximately 4000 characters each, without splitting individual context entries across chunk boundaries.

#### Scenario: Split contexts into chunks
- **WHEN** 50 context entries with a total of 12000 characters are collected
- **THEN** the system creates 3 chunks, each approximately 4000 characters, with context entries kept intact within each chunk

#### Scenario: Single chunk when total is small
- **WHEN** the total character count of all context entries is 3000 characters
- **THEN** the system creates a single chunk containing all context entries

#### Scenario: Large individual context entry
- **WHEN** a single context entry exceeds 4000 characters
- **THEN** the context entry is placed in its own chunk without being split

### Requirement: Fact extraction from chunks (Stage 1)
The system SHALL send each chunk to the LLM with a fact extraction prompt, requesting a bulleted list of facts about the specified term.

#### Scenario: Extract facts from a chunk
- **WHEN** a chunk containing contexts about the term "アリス" is sent to the LLM
- **THEN** the LLM returns a bulleted list of facts such as "- 王国の第三王女\n- 剣術の達人\n- ボブとは幼馴染"

#### Scenario: No relevant facts in chunk
- **WHEN** a chunk contains the term but no meaningful information about it (e.g., only passing mentions)
- **THEN** the LLM returns an empty or minimal bulleted list

### Requirement: Recursive fact aggregation
The system SHALL recursively aggregate extracted facts when the combined facts exceed 4000 characters, re-chunking and re-extracting until the total fits within 4000 characters.

#### Scenario: Facts fit within limit after first extraction
- **WHEN** Stage 1 produces a combined facts text of 2000 characters
- **THEN** the system proceeds directly to the final summary stage without further recursion

#### Scenario: Facts exceed limit requiring re-aggregation
- **WHEN** Stage 1 produces a combined facts text of 8000 characters
- **THEN** the system splits the facts into chunks of approximately 4000 characters each, sends each chunk to the LLM for further fact aggregation, and repeats until the total is within 4000 characters

#### Scenario: Recursion limit reached
- **WHEN** fact aggregation has been performed 5 times and the total still exceeds 4000 characters
- **THEN** the system stops recursion and proceeds to the final summary stage with the current facts

### Requirement: Final summary generation
The system SHALL generate a final summary by sending the aggregated facts to the LLM with a summary generation prompt, producing a 1-2 sentence explanation of the term.

#### Scenario: Generate final summary from facts
- **WHEN** the aggregated facts for "アリス" are "- 王国の第三王女\n- 剣術の達人\n- ボブとは幼馴染\n- 第5章で記憶を失う"
- **THEN** the LLM generates a concise 1-2 sentence summary and the system returns it as a JSON response with a "summary" field

### Requirement: Fact extraction prompt construction
The system SHALL construct a fact extraction prompt that instructs the LLM to list facts about the specified term from the provided context chunk.

#### Scenario: Build fact extraction prompt
- **WHEN** building a fact extraction prompt for the term "聖印" with a chunk of context text
- **THEN** the prompt includes the term in a `<term>` tag, the chunk in a `<context>` tag, and instructs the LLM to return facts as a JSON response with a "facts" field containing a bulleted list

### Requirement: Final summary prompt construction
The system SHALL construct a final summary prompt that instructs the LLM to generate a concise explanation from the aggregated facts.

#### Scenario: Build final summary prompt
- **WHEN** building a final summary prompt for the term "聖印" with aggregated facts
- **THEN** the prompt includes the term in a `<term>` tag, the facts in a `<facts>` tag, and instructs the LLM to return a JSON response with a "summary" field containing a 1-2 sentence explanation

### Requirement: JSON decode failure observability
When the LLM response cannot be decoded as JSON (the system currently falls back to treating the raw response as the summary text), the system SHALL log the decode failure at WARNING level via `Logger('llm_summary')` including the response body length and a short prefix of the raw text (sufficient for prompt tuning, but bounded so logs do not grow unbounded). The system SHALL retain the existing fallback behaviour: the raw text is still used as the summary so the user-visible feature continues to work.

#### Scenario: Invalid JSON triggers a log record
- **WHEN** the LLM returns a body that fails `jsonDecode`
- **THEN** a WARNING-level `LogRecord` is emitted on `Logger('llm_summary')` whose message includes `length=<N>` and a prefix of at most 200 characters of the raw response

#### Scenario: Fallback to raw text preserved
- **WHEN** the JSON decode fails and the fallback path is taken
- **THEN** the system uses the raw response string as the summary value, preserving the prior user-visible behaviour

#### Scenario: Successful decode does not log
- **WHEN** the LLM response is valid JSON
- **THEN** no decode-failure log record is emitted

### Requirement: Release LLM client resources after summary generation
The summary service SHALL invoke `LlmClient.releaseResources()` after every summary generation attempt, regardless of whether the generation succeeded or failed. The release call SHALL be awaited so that the summary operation does not return to its caller until the release attempt has completed. Any exception raised by `releaseResources()` SHALL be caught and suppressed inside the service so that release failures never propagate to the user-facing error path; the original generation result (or its original exception) SHALL be preserved.

#### Scenario: Release is invoked after successful generation
- **WHEN** the summary service completes a generation successfully and is about to return the summary to its caller
- **THEN** `LlmClient.releaseResources()` is awaited before the service method returns the summary

#### Scenario: Release is invoked after failed generation
- **WHEN** the summary pipeline raises an exception during generation
- **THEN** `LlmClient.releaseResources()` is awaited before the original exception is rethrown to the caller

#### Scenario: Release failure does not affect the user-visible result
- **WHEN** `LlmClient.releaseResources()` itself raises an exception
- **THEN** the service catches and suppresses that exception, and the original generation outcome (the returned summary or the original generation exception) is preserved unchanged

#### Scenario: Release failure does not corrupt the original generation exception
- **WHEN** generation raised exception `E1` and `releaseResources()` raised exception `E2`
- **THEN** the caller observes `E1` (not `E2`), so that the cause of the user-visible failure remains the actual generation failure

### Requirement: Progress notification during summary generation

`LlmSummaryPipeline.generate` SHALL accept an optional progress callback parameter. When provided, the pipeline SHALL invoke the callback before each LLM call so that callers can observe which phase the pipeline is in and how many LLM calls remain in the current phase. When the callback is not provided, the pipeline SHALL behave exactly as before with no observable difference.

Progress events SHALL be expressed as instances of `AnalysisProgress` (a sealed type) and SHALL include:

- A fact-extraction event carrying `current` (1-indexed chunk index), `total` (chunk count in the current round), and `round` (1 for the initial extraction, 2 or greater for recursive refinement rounds).
- A final-summary event with no payload, emitted immediately before the final summary LLM call.

The pipeline SHALL NOT emit any progress event for the context-search step (which happens outside the pipeline) or for repository persistence.

#### Scenario: Initial fact extraction emits one event per chunk

- **WHEN** the pipeline processes 3 chunks during the initial fact-extraction phase
- **THEN** the callback is invoked 3 times in order with `round = 1`, `total = 3`, and `current` of 1, 2, 3 respectively, each emission occurring before the corresponding LLM call

#### Scenario: Recursive refinement increments round and resets current

- **WHEN** the initial extraction produces facts that still exceed the chunk size, triggering a refinement pass with 2 chunks
- **THEN** the callback is invoked with `round = 2`, `total = 2`, and `current` of 1 then 2 (in that order), after the round-1 events have completed

#### Scenario: Final summary event is the last progress notification

- **WHEN** all fact-extraction rounds complete and the pipeline is about to invoke the final summary prompt
- **THEN** the callback is invoked exactly once with an `AnalysisGeneratingFinalSummary` event, and no further progress events are emitted before the pipeline returns

#### Scenario: Empty contexts still emit the final summary event

- **WHEN** `generate` is called with an empty `contexts` list (so no fact extraction is performed)
- **THEN** the callback is invoked exactly once with `AnalysisGeneratingFinalSummary` before the single LLM call

#### Scenario: Callback omitted preserves prior behavior

- **WHEN** `generate` is called without supplying a progress callback
- **THEN** the pipeline produces the same summary string as before with no thrown exception, and no internal attempt is made to invoke a null callback

#### Scenario: Progress event ordering precedes the LLM call

- **WHEN** the callback is supplied and a chunk is about to be sent to the LLM
- **THEN** the callback receives the matching event before `LlmClient.generate` is invoked for that chunk (so observers can update UI ahead of the network call)

