## ADDED Requirements

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
