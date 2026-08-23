## MODIFIED Requirements

### Requirement: JSON decode failure observability

When the LLM response cannot be decoded as JSON (the system currently falls back to treating the raw response as the summary text), the system SHALL log the decode failure at WARNING level via `Logger('llm_summary')` including the response body length and a short prefix of the raw text (sufficient for prompt tuning, but bounded so logs do not grow unbounded). The system SHALL retain the existing fallback behaviour for this case: the raw text is still used as the value so the user-visible feature continues to work when the model returns a plain (non-JSON) response.

When the response decodes to a JSON object whose requested key holds an **array of strings**, the system SHALL treat the response as a valid structured decode: it SHALL normalize the array into a single string by joining the elements with a newline (`\n`) in order, without adding or stripping any bullet prefix, and return that string as the value. The normalized value SHALL be reported as coming from a successful structured decode (not from the raw-text fallback), so that it is eligible for the same persistence policy as a plain string value (see `llm-summary-fact-cache`). This accommodates runtimes that do not enforce the requested `format` schema (e.g. Ollama's MLX runner), where a capable model returns `{"facts": ["fact1", "fact2"]}` even though a single string was requested.

Additionally, when the response **does** decode to a JSON object but does not yield a string value (nor a normalizable array of strings) for the requested key — that is, the key is absent, or the key is present but its value is not a string and not an array of strings (e.g. `null`, a number, an object, an empty array, or an array containing a non-string element) — the system SHALL treat the response as malformed. In this malformed case the system SHALL NOT use the raw JSON text as the value and SHALL NOT persist it as the summary/facts; it SHALL instead raise a typed `LlmResponseFormatException` and log the condition at WARNING level via `Logger('llm_summary')`. This closes the prior defect where a valid-JSON-but-wrong-shape response (e.g. `{"summary": null}`) caused the raw JSON string to be persisted as the summary.

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
