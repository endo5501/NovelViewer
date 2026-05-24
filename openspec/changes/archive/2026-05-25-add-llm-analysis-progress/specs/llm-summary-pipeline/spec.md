## ADDED Requirements

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
