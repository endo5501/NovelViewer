## ADDED Requirements

### Requirement: Per-stage structured output schema

The pipeline SHALL request a response schema on every LLM generation call, naming the field it will read back: Stage-1 fact extraction SHALL request a schema for the field `facts`, and final summary generation SHALL request a schema for the field `summary`. The prompt text SHALL continue to state the expected JSON shape, so that the instruction given to the model and the schema enforced on it agree.

#### Scenario: Fact extraction requests the facts schema

- **WHEN** the pipeline performs Stage-1 fact extraction for a context chunk
- **THEN** the `generate` call SHALL carry a schema naming the field `facts`

#### Scenario: Final summary requests the summary schema

- **WHEN** the pipeline generates the final summary from aggregated facts
- **THEN** the `generate` call SHALL carry a schema naming the field `summary`

### Requirement: Single retry on generation failure

When obtaining a value from the LLM fails — either the generation request itself raises, or the response is rejected as malformed by the response parser — the system SHALL retry exactly once with an identical request before treating it as failed. This SHALL apply both to Stage-1 fact-extraction calls and to the final summary call. The retry SHALL NOT alter the prompt, the schema, or any generation parameter, and SHALL NOT introduce a delay. If the retry also fails, the failure SHALL be propagated to the caller.

The raw-text fallback (the response failed `jsonDecode`) is not a failure for this purpose and SHALL NOT trigger a retry; it yields a usable value that is merely not eligible for caching.

#### Scenario: A transient generation failure is recovered by the retry

- **WHEN** a Stage-1 fact-extraction request raises and the identical retry succeeds
- **THEN** the pipeline SHALL use the retry's result and SHALL NOT surface an error for that call

#### Scenario: A malformed response is recovered by the retry

- **WHEN** a Stage-1 fact-extraction response decodes to a JSON object whose `facts` value is an array (rejected as malformed) and the identical retry returns a well-formed response
- **THEN** the pipeline SHALL use the retry's result and SHALL NOT surface an error for that call

#### Scenario: A persistent generation failure is propagated after one retry

- **WHEN** a final summary request raises and the identical retry also raises
- **THEN** the system SHALL propagate the failure, having issued exactly two generation requests for that call

#### Scenario: A successful call is not retried

- **WHEN** a Stage-1 fact-extraction call succeeds on the first attempt
- **THEN** exactly one generation request SHALL be issued for that call

#### Scenario: The raw-text fallback does not trigger a retry

- **WHEN** a Stage-1 fact-extraction response fails `jsonDecode` and the raw-text fallback is taken
- **THEN** exactly one generation request SHALL be issued for that call

### Requirement: File-level extraction failure isolation

When Stage-1 fact extraction for one source file fails (after its retry), the system SHALL record that file as failed and SHALL continue extracting the remaining in-scope files, rather than aborting the run at the first failure. The purpose is to leave the successfully extracted files in the fact cache so that a later re-run pays only for the files that failed.

#### Scenario: Extraction continues past a failed file

- **WHEN** five files are in scope and extraction for the third file fails after its retry
- **THEN** the system SHALL still attempt extraction for the fourth and fifth files, and their successful results SHALL be cached

#### Scenario: A re-run after a partial failure only re-extracts the failed files

- **WHEN** a run failed with one file failing out of five, and the user runs the same analysis again without any source file having changed
- **THEN** the system SHALL serve the four succeeded files from the fact cache and SHALL issue extraction calls only for the file that previously failed

### Requirement: Analysis fails without persisting when any file failed

When at least one in-scope source file failed Stage-1 extraction, the system SHALL NOT invoke final summary generation and SHALL NOT save a snapshot. The analysis SHALL terminate as a typed failure carrying the number of failed files and the error raised by the first file that failed, so that no incomplete summary is persisted, no generation call is spent on a result that would be discarded, and the underlying cause stays diagnosable.

#### Scenario: A failed file prevents summary generation and persistence

- **WHEN** one of five in-scope files failed Stage-1 extraction after its retry
- **THEN** the system SHALL NOT issue a final summary generation call, SHALL NOT write a `word_summaries` row, and SHALL report a failure indicating one failed file whose text includes that file's underlying error

#### Scenario: A fully successful run persists as before

- **WHEN** every in-scope file completed Stage-1 extraction
- **THEN** the system SHALL generate the final summary and save the snapshot exactly as before

## MODIFIED Requirements

### Requirement: Final summary generation
The system SHALL generate a final summary by sending the aggregated facts to the LLM with a summary generation prompt, producing a 1-2 sentence explanation of the term. When the aggregated facts are empty — no in-scope file produced any facts — the system SHALL NOT issue the final summary generation call and SHALL instead fail the analysis, so that a summary is never fabricated from an empty evidence set nor persisted.

#### Scenario: Generate final summary from facts
- **WHEN** the aggregated facts for "アリス" are "- 王国の第三王女\n- 剣術の達人\n- ボブとは幼馴染\n- 第5章で記憶を失う"
- **THEN** the LLM generates a concise 1-2 sentence summary and the system returns it as a JSON response with a "summary" field

#### Scenario: Empty aggregated facts do not reach the LLM
- **WHEN** the aggregated facts are empty because no in-scope file produced any facts
- **THEN** the system SHALL NOT issue a final summary generation call, SHALL NOT save a snapshot, and SHALL fail the analysis

### Requirement: JSON decode failure observability

When the LLM response cannot be decoded as JSON (the system currently falls back to treating the raw response as the summary text), the system SHALL log the decode failure at WARNING level via `Logger('llm_summary')` including the response body length and a short prefix of the raw text (sufficient for prompt tuning, but bounded so logs do not grow unbounded). The system SHALL retain the existing fallback behaviour for this case: the raw text is still used as the value so the user-visible feature continues to work when the model returns a plain (non-JSON) response.

Additionally, when the response **does** decode to a JSON object but does not yield a string value for the requested key — that is, the key is absent, or the key is present but its value is not a string (e.g. `null`, a number, an object, or an array) — the system SHALL treat the response as malformed. In this malformed case the system SHALL NOT use the raw JSON text as the value and SHALL NOT persist it as the summary/facts; it SHALL instead raise a typed `LlmResponseFormatException` and log the condition at WARNING level via `Logger('llm_summary')`. This closes the prior defect where a valid-JSON-but-wrong-shape response (e.g. `{"summary": null}`) caused the raw JSON string to be persisted as the summary.

The parse result SHALL additionally convey whether the value came from a successful structured decode or from the raw-text fallback, so that callers can apply different persistence policies to the two outcomes (see the fact-cache write condition in `llm-summary-fact-cache`). The value returned in the fallback case SHALL remain the raw text, unchanged from the behaviour above.

#### Scenario: Invalid JSON triggers a log record
- **WHEN** the LLM returns a body that fails `jsonDecode`
- **THEN** a WARNING-level `LogRecord` is emitted on `Logger('llm_summary')` whose message includes `length=<N>` and a prefix of at most 200 characters of the raw response

#### Scenario: Fallback to raw text preserved for non-JSON responses
- **WHEN** the JSON decode fails (the model returned plain, non-JSON text) and the fallback path is taken
- **THEN** the system uses the raw response string as the value, preserving the prior user-visible behaviour

#### Scenario: Successful decode with a valid string value does not log or throw
- **WHEN** the LLM response is valid JSON whose requested key holds a string value
- **THEN** no decode-failure log record is emitted, no exception is raised, and the string value is returned

#### Scenario: Valid JSON with a non-string field value is rejected
- **WHEN** the response decodes to a JSON object where the requested key is present but its value is not a string (e.g. `{"summary": null}`)
- **THEN** the system raises an `LlmResponseFormatException`, does NOT return or persist the raw JSON text as the value, and logs the condition at WARNING level

#### Scenario: Valid JSON missing the requested field is rejected
- **WHEN** the response decodes to a JSON object that does not contain the requested key
- **THEN** the system raises an `LlmResponseFormatException` rather than persisting the raw JSON text as the value

#### Scenario: The fallback outcome is distinguishable from a structured decode
- **WHEN** the raw-text fallback path is taken for a Stage-1 fact-extraction response
- **THEN** the parse result SHALL indicate that the value came from the fallback rather than from a successful structured decode
