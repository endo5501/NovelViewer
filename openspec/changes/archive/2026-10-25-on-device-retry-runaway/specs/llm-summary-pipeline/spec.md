## ADDED Requirements

### Requirement: An unreadable final summary is asked for once more and then fails the analysis
Where the request that produces the word's final summary returns an answer that does not parse, the pipeline SHALL issue that request once more and SHALL use the second answer where it parses.

This stage alone is treated this way, because its value is what the reader sees: it is saved as the word's summary with nothing downstream judging it. An answer that does not parse is no longer used as a summary at all, so a second request is the only way such a run can still produce one.

Exactly one further request SHALL be made. Where the second answer also does not parse, the analysis SHALL fail without saving a summary, and the reader SHALL be told that the summary could not be read. A third generation on the slowest provider is not made: two unreadable answers to the same prompt say more about the model than a third would change.

Where the second request fails outright, the analysis SHALL fail in the same way. The first answer is not kept, because it is not readable and there is nothing else to show; the failure of the second request SHALL be kept for the log.

This applies to every provider. A server-backed model that replies in prose to a request for a structured answer is not producing a summary the pipeline can trust either, and one rule for every provider keeps the pipeline from needing to know which provider answered.

This request is counted separately from the single retry that answers a failure. That retry is provoked by a request that raised or by a response the parser rejected; this one is provoked by a response that did not decode. Both can therefore apply to the same summary, and the stage SHALL be understood to issue up to three generation requests: two from the retry on failure, and one more when what the second produced could not be read. Each of them may be answered by several generations inside a provider that makes further requests of its own, such as the on-device provider answering a refusal.

An extraction that cannot be read SHALL NOT be re-requested this way. It is already marked unstructured, which keeps it out of the fact cache, and it costs the reader nothing beyond a re-extraction.

#### Scenario: A readable answer is taken as it stands
- **WHEN** the final summary request returns an answer that parses
- **THEN** exactly one request SHALL be made, and that answer SHALL be used

#### Scenario: An unreadable answer is replaced
- **WHEN** the final summary request returns an answer that does not parse, and a second request returns one that does
- **THEN** the second answer SHALL be used

#### Scenario: Two unreadable answers fail the analysis
- **WHEN** neither the first nor the second final summary answer parses
- **THEN** no third request SHALL be made, no snapshot SHALL be saved, and the analysis SHALL fail with a reason saying the summary could not be read

#### Scenario: A failed second request fails the analysis
- **WHEN** the first final summary answer does not parse and the second request fails
- **THEN** no snapshot SHALL be saved, and the analysis SHALL fail with a reason saying the summary could not be read

#### Scenario: A server-backed answer in prose fails the analysis
- **WHEN** a server-backed provider answers both final summary requests with plain prose rather than a JSON object
- **THEN** no snapshot SHALL be saved, and the analysis SHALL fail with a reason saying the summary could not be read

#### Scenario: An unreadable extraction is not re-requested
- **WHEN** a Stage-1 fact extraction returns an answer that does not parse
- **THEN** it SHALL be marked as coming from the raw-text fallback, and no further request SHALL be made for it

## MODIFIED Requirements

### Requirement: Final summary generation
The system SHALL generate a final summary by sending the aggregated facts to the LLM with a summary generation prompt, producing a 1-2 sentence explanation of the term. When the aggregated facts are empty — no in-scope file produced any facts — the system SHALL NOT issue the final summary generation call and SHALL instead fail the analysis, so that a summary is never fabricated from an empty evidence set nor persisted.

The final summary SHALL be taken only from an answer that yields the summary as a structured value. An answer that cannot be read that way SHALL NOT become the word's summary, as the requirement that an unreadable final summary is asked for once more and then fails the analysis describes.

#### Scenario: Generate final summary from facts
- **WHEN** the aggregated facts for "アリス" are "- 王国の第三王女\n- 剣術の達人\n- ボブとは幼馴染\n- 第5章で記憶を失う"
- **THEN** the LLM generates a concise 1-2 sentence summary and the system returns it as a JSON response with a "summary" field

#### Scenario: Empty aggregated facts do not reach the LLM
- **WHEN** the aggregated facts are empty because no in-scope file produced any facts
- **THEN** the system SHALL NOT issue a final summary generation call, SHALL NOT save a snapshot, and SHALL fail the analysis

#### Scenario: An unreadable final summary is not saved
- **WHEN** no final summary answer for "記憶人" can be read as a structured value
- **THEN** the system SHALL NOT save a snapshot, and SHALL fail the analysis with a reason saying the summary could not be read

### Requirement: JSON decode failure observability

When the LLM response cannot be decoded as JSON, the system SHALL log the decode failure at WARNING level via `Logger('llm_summary')` including the response body length and a short prefix of the raw text (sufficient for prompt tuning, but bounded so logs do not grow unbounded). For a Stage-1 fact-extraction response the system SHALL retain the existing fallback behaviour: the raw text is still used as the value, so that one file whose model replied in plain (non-JSON) text still contributes its facts to the current run. For the final summary the raw text SHALL NOT be used as the summary; the decode failure SHALL be reported as an answer that could not be read, as the requirement that an unreadable final summary is asked for once more and then fails the analysis describes.

The raw text of a final summary is withdrawn as a fallback because it is the one value the reader sees as it stands, saved as the word's summary with nothing downstream judging it. Falling back to it used to mean the model had replied in prose. It can as well mean an answer that never closed, such as one a model wrote until its response cap; once a provider gives up a schema constraint to get an answer at all, nothing guarantees the answer it returns is an object. A Stage-1 value is not in that position: it is read by the later stages rather than by the reader, and its fallback already keeps it out of the fact cache.

When the response decodes to a JSON object whose requested key holds an **array of strings**, the system SHALL treat the response as a valid structured decode: it SHALL normalize the array into a single string by joining the elements with a newline (`\n`) in order, without adding or stripping any bullet prefix, and return that string as the value. The normalized value SHALL be reported as coming from a successful structured decode (not from the raw-text fallback), so that it is eligible for the same persistence policy as a plain string value (see `llm-summary-fact-cache`). This accommodates runtimes that do not enforce the requested `format` schema (e.g. Ollama's MLX runner), where a capable model returns `{"facts": ["fact1", "fact2"]}` even though a single string was requested.

Additionally, when the response **does** decode to a JSON object but does not yield a string value (nor a normalizable array of strings) for the requested key — that is, the key is absent, or the key is present but its value is not a string and not an array of strings (e.g. `null`, a number, an object, an empty array, or an array containing a non-string element) — the system SHALL treat the response as malformed. In this malformed case the system SHALL NOT use the raw JSON text as the value and SHALL NOT persist it as the summary/facts; it SHALL instead raise a typed `LlmResponseFormatException` and log the condition at WARNING level via `Logger('llm_summary')`. This closes the prior defect where a valid-JSON-but-wrong-shape response (e.g. `{"summary": null}`) caused the raw JSON string to be persisted as the summary.

The parse result SHALL additionally convey whether the value came from a successful structured decode or from the raw-text fallback, so that callers can apply different persistence policies to the two outcomes (see the fact-cache write condition in `llm-summary-fact-cache`). The value returned in the fallback case SHALL remain the raw text, unchanged from the behaviour above.

#### Scenario: Invalid JSON triggers a log record
- **WHEN** the LLM returns a body that fails `jsonDecode`
- **THEN** a WARNING-level `LogRecord` is emitted on `Logger('llm_summary')` whose message includes `length=<N>` and a prefix of at most 200 characters of the raw response

#### Scenario: Fallback to raw text preserved for non-JSON responses
- **WHEN** the JSON decode of a Stage-1 fact-extraction response fails (the model returned plain, non-JSON text) and the fallback path is taken
- **THEN** the system uses the raw response string as the value, preserving the prior behaviour

#### Scenario: A non-JSON final summary is not used as the summary
- **WHEN** the JSON decode of a final summary response fails
- **THEN** the raw response string SHALL NOT be used as the word's summary

#### Scenario: Successful decode with a valid string value does not log or throw
- **WHEN** the LLM response is valid JSON whose requested key holds a string value
- **THEN** no decode-failure log record is emitted, no exception is raised, and the string value is returned

#### Scenario: An array of strings is normalized and accepted as structured
- **WHEN** the response decodes to a JSON object where the requested key holds a non-empty array whose every element is a string (e.g. `{"facts": ["fact1", "fact2"]}`)
- **THEN** the system joins the elements with `\n` in order into a single string, returns that string as the value, reports it as a successful structured decode (not a raw-text fallback), and raises no exception

#### Scenario: Valid JSON with a non-string, non-array field value is rejected
- **WHEN** the response decodes to a JSON object where the requested key is present but its value is not a string and not an array of strings (e.g. `{"summary": null}`)
- **THEN** the system raises an `LlmResponseFormatException`, does NOT return or persist the raw JSON text as the value, and logs the condition at WARNING level

#### Scenario: An empty array or an array with a non-string element is rejected
- **WHEN** the response decodes to a JSON object where the requested key holds an empty array (`{"facts": []}`) or an array containing at least one non-string element (e.g. `{"facts": ["ok", 123]}`)
- **THEN** the system raises an `LlmResponseFormatException`, does NOT return or persist the raw JSON text as the value, and logs the condition at WARNING level

#### Scenario: Valid JSON missing the requested field is rejected
- **WHEN** the response decodes to a JSON object that does not contain the requested key
- **THEN** the system raises an `LlmResponseFormatException` rather than persisting the raw JSON text as the value

#### Scenario: The fallback outcome is distinguishable from a structured decode
- **WHEN** the raw-text fallback path is taken for a Stage-1 fact-extraction response
- **THEN** the parse result SHALL indicate that the value came from the fallback rather than from a successful structured decode

## REMOVED Requirements

### Requirement: A final summary that cannot be read is asked for once more
**Reason**: It kept an unreadable first answer as the word's summary when the second answer was unreadable too or the second request failed. An unreadable answer saved as a summary is shown to the reader as though it were one, whatever it contains. The second request is kept; what happens after it is replaced.
**Migration**: Replaced by "An unreadable final summary is asked for once more and then fails the analysis", which issues the same second request and fails the analysis, without saving a summary, where no answer can be read.
