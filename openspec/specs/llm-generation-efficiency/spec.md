## Purpose

Make Ollama generation requests efficient by disabling thinking-token generation (which dominated measured summary time while never reaching the response) and bounding output length, with a version-compatibility fallback for servers that reject the `think` parameter.

## Requirements

### Requirement: Thinking disabled on Ollama generate requests

`OllamaClient.generate` SHALL include `"think": false` in the request body of every `POST /api/generate` call, so that thinking-capable models do not spend time generating reasoning tokens that are discarded from the response. The `releaseResources` unload request (`keep_alive: 0`) SHALL NOT include the `think` field.

#### Scenario: generate request carries think:false

- **WHEN** `OllamaClient.generate` is called with any prompt
- **THEN** the JSON body sent to `/api/generate` SHALL contain `"think": false` alongside `model`, `prompt`, and `stream: false`

#### Scenario: unload request does not carry think

- **WHEN** `OllamaClient.releaseResources` is called
- **THEN** the JSON body sent to `/api/generate` SHALL contain `keep_alive: 0` and SHALL NOT contain a `think` field

### Requirement: Output token cap on Ollama generate requests

`OllamaClient.generate` SHALL include `"options": {"num_predict": 1024}` in the request body of every `POST /api/generate` call, bounding the number of generated tokens. The cap value SHALL be a compile-time constant of `OllamaClient` (no settings UI).

#### Scenario: generate request carries num_predict

- **WHEN** `OllamaClient.generate` is called with any prompt
- **THEN** the JSON body sent to `/api/generate` SHALL contain an `options` object whose `num_predict` equals 1024

### Requirement: Fallback for Ollama versions rejecting the think parameter

When a `/api/generate` call fails with HTTP status 400 and an error body that mentions the `think` parameter, `OllamaClient` SHALL retry the request exactly once with the `think` field removed (other fields unchanged). After such a fallback has occurred, the same `OllamaClient` instance SHALL omit the `think` field from all subsequent `generate` requests, so that each later call is sent only once. All other errors — including non-400 statuses whose body happens to contain `think` (e.g. a 404 for a model whose name contains "thinking") — SHALL be propagated unchanged without retry.

#### Scenario: think-related error triggers a single retry

- **WHEN** the first `/api/generate` response has HTTP status 400 and its body contains the string `think`
- **THEN** the client SHALL send the same request once more without the `think` field, and SHALL return that retry's successful response

#### Scenario: non-400 errors mentioning think are not retried

- **WHEN** a `/api/generate` response has a non-200, non-400 status (e.g. 404) whose body contains the string `think`
- **THEN** the client SHALL propagate the error without sending any retry request

#### Scenario: subsequent calls skip think after fallback

- **WHEN** a prior `generate` call on the same client instance already fell back due to a think-related error
- **THEN** later `generate` calls SHALL send their request without the `think` field and SHALL NOT perform a duplicate first attempt with `think`

#### Scenario: unrelated errors are not retried

- **WHEN** a `/api/generate` response has a non-200 status and its body does not contain the string `think`
- **THEN** the client SHALL propagate the error without sending any retry request
