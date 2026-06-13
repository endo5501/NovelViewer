## MODIFIED Requirements

### Requirement: JSON decode failure observability

When the LLM response cannot be decoded as JSON (the system currently falls back to treating the raw response as the summary text), the system SHALL log the decode failure at WARNING level via `Logger('llm_summary')` including the response body length and a short prefix of the raw text (sufficient for prompt tuning, but bounded so logs do not grow unbounded). The system SHALL retain the existing fallback behaviour for this case: the raw text is still used as the value so the user-visible feature continues to work when the model returns a plain (non-JSON) response.

Additionally, when the response **does** decode to a JSON object but does not yield a string value for the requested key — that is, the key is absent, or the key is present but its value is not a string (e.g. `null`, a number, an object, or an array) — the system SHALL treat the response as malformed. In this malformed case the system SHALL NOT use the raw JSON text as the value and SHALL NOT persist it as the summary/facts; it SHALL instead raise a typed `LlmResponseFormatException` and log the condition at WARNING level via `Logger('llm_summary')`. This closes the prior defect where a valid-JSON-but-wrong-shape response (e.g. `{"summary": null}`) caused the raw JSON string to be persisted as the summary.

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
