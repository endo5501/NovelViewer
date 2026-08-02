## ADDED Requirements

### Requirement: Structured output schema on LLM generation requests

`LlmClient.generate` SHALL accept an optional response-schema argument that describes a JSON object carrying exactly one required field of type string, whose name is supplied by the caller. When the argument is omitted, every client SHALL behave exactly as before (no schema is transmitted).

`OllamaClient.generate` SHALL, when a schema is supplied, include a `format` field in the `POST /api/generate` request body holding the equivalent JSON Schema — an object type whose `properties` contains the named field typed as `string`, with that field listed in `required`. The `format` field SHALL be sent unconditionally when a schema is supplied; no capability probe, version check, or removal-and-retry fallback SHALL be performed for it. The `releaseResources` unload request SHALL NOT include a `format` field.

`OpenAiCompatibleClient.generate` SHALL accept the schema argument and ignore it, leaving its request body unchanged.

#### Scenario: Ollama generate request carries the format schema

- **WHEN** `OllamaClient.generate` is called with a prompt and a schema naming the field `facts`
- **THEN** the JSON body sent to `/api/generate` SHALL contain a `format` object equal to `{"type":"object","properties":{"facts":{"type":"string"}},"required":["facts"]}`, alongside `model`, `prompt`, `stream: false`, `think: false`, and `options.num_predict`

#### Scenario: Ollama generate request without a schema omits format

- **WHEN** `OllamaClient.generate` is called with a prompt and no schema argument
- **THEN** the JSON body sent to `/api/generate` SHALL NOT contain a `format` field

#### Scenario: Unload request does not carry format

- **WHEN** `OllamaClient.releaseResources` is called
- **THEN** the JSON body sent to `/api/generate` SHALL contain `keep_alive: 0` and SHALL NOT contain a `format` field

#### Scenario: An error mentioning format is propagated without retry

- **WHEN** a `/api/generate` call made with a schema fails with HTTP status 400 whose body mentions `format` but does not mention `think`
- **THEN** the client SHALL propagate the error without sending any retry request and SHALL NOT disable schema transmission for later calls

#### Scenario: OpenAI-compatible client ignores the schema

- **WHEN** `OpenAiCompatibleClient.generate` is called with a prompt and a schema naming the field `summary`
- **THEN** the JSON body sent to `/chat/completions` SHALL contain only `model` and `messages`, with no `response_format` or equivalent field
