## Purpose

Make the LLM HTTP clients robust against charset ambiguity, malformed response shapes, and resource leaks by decoding bodies as UTF-8, validating response structure with typed exceptions, and injecting a shared, provider-managed `http.Client`.
## Requirements
### Requirement: Charset-independent response decoding

LLM HTTP clients (`OpenAiCompatibleClient`, `OllamaClient`) SHALL decode every response body as UTF-8 from the raw bytes (`utf8.decode(response.bodyBytes)`) rather than reading `response.body`. This SHALL apply to all parse points, including success responses, model-list responses, and the bodies embedded in non-200 error messages. The clients SHALL NOT rely on the `Content-Type` charset, which defaults to latin1 when absent and corrupts non-ASCII (e.g. Japanese) text.

#### Scenario: UTF-8 JSON body without charset is decoded correctly

- **WHEN** an OpenAI-compatible endpoint returns a UTF-8 JSON body whose `Content-Type` is a bare `application/json` (no charset), and the content contains Japanese characters
- **THEN** the client decodes the bytes as UTF-8 and returns the Japanese text intact (no mojibake)

#### Scenario: UTF-8 model list without charset is decoded correctly

- **WHEN** the Ollama `GET /api/tags` response carries Japanese-containing model metadata in a UTF-8 body without a charset declaration
- **THEN** the parsed model names preserve the original UTF-8 characters

#### Scenario: Error body in exception message is UTF-8 decoded

- **WHEN** the server responds with a non-200 status and a UTF-8 body containing non-ASCII characters
- **THEN** the thrown exception's message includes the body decoded as UTF-8 (not latin1-garbled)

### Requirement: Response shape validation with typed exceptions

LLM HTTP clients SHALL validate the structure of decoded responses before extracting values, and SHALL convert any structural mismatch into a typed, descriptive exception (`LlmResponseFormatException`) instead of letting a raw `RangeError`, `TypeError`, or `CastError` propagate. Validation SHALL cover: the top-level JSON being an object; for OpenAI, `choices` being a non-empty list and `choices[0].message.content` being a string; for Ollama, `models` being a list of objects each with a string `name`, and `generate` responses having a string `response` field.

#### Scenario: Empty choices array raises a typed exception

- **WHEN** an OpenAI-compatible response decodes to `{"choices": []}`
- **THEN** the client throws an `LlmResponseFormatException` describing the missing/empty `choices`, and no `RangeError` reaches the caller

#### Scenario: Missing message content raises a typed exception

- **WHEN** an OpenAI-compatible response has `choices[0]` without a string `message.content`
- **THEN** the client throws an `LlmResponseFormatException` rather than a `CastError`

#### Scenario: Non-list models field raises a typed exception

- **WHEN** an Ollama `/api/tags` response decodes to a JSON where `models` is not a list (e.g. `{"models": null}`)
- **THEN** the client throws an `LlmResponseFormatException` rather than a `TypeError`

#### Scenario: Non-object top-level JSON raises a typed exception

- **WHEN** a response decodes to a JSON array or scalar instead of an object
- **THEN** the client throws an `LlmResponseFormatException` describing the unexpected shape

#### Scenario: Well-formed response still parses normally

- **WHEN** the response matches the expected shape
- **THEN** the client returns the extracted value exactly as before, with no exception

### Requirement: HTTP client dependency injection for LLM clients

LLM clients SHALL receive their `http.Client` from the shared `httpClientProvider` rather than constructing their own. The provider that builds LLM clients (`llmClientProvider`) SHALL inject `ref.watch(httpClientProvider)` into both `OpenAiCompatibleClient` and `OllamaClient`. No code path that constructs an LLM client for production use SHALL create a new `http.Client()` that is never closed. Reconstructing the LLM client on configuration change SHALL reuse the shared, provider-managed client rather than leaking a new one per change.

#### Scenario: Provider injects the shared client

- **WHEN** `llmClientProvider` builds an `OpenAiCompatibleClient` or `OllamaClient`
- **THEN** the client uses the instance returned by `httpClientProvider`, and does not instantiate its own `http.Client`

#### Scenario: Config change does not leak clients

- **WHEN** the LLM configuration changes repeatedly, causing `llmClientProvider` to rebuild the LLM client multiple times
- **THEN** each rebuilt LLM client shares the single provider-managed `http.Client`, so no unclosed `http.Client` instances accumulate

#### Scenario: Shared client lifecycle remains provider-owned

- **WHEN** the `httpClientProvider` is disposed
- **THEN** the underlying `http.Client` is closed by the provider's `onDispose`, and the LLM clients do not separately own or close it
