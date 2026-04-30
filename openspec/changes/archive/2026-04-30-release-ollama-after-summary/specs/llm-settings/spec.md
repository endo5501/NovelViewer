## ADDED Requirements

### Requirement: LLM client resource release contract
The `LlmClient` abstraction SHALL expose a `releaseResources()` method that callers can invoke to ask the underlying LLM backend to free any resources held on behalf of the client (such as GPU-resident model state). The contract SHALL provide a default no-op implementation so that backends without releasable resources are conformant without any code changes. Implementations whose backend holds releasable resources SHALL override the method.

#### Scenario: Default implementation is no-op for backends without releasable resources
- **WHEN** the `LlmClient` interface's default `releaseResources()` implementation is invoked
- **THEN** the call completes successfully without contacting any backend and without raising an exception

#### Scenario: OpenAI-compatible client uses the default no-op
- **WHEN** `releaseResources()` is invoked on an `OpenAiCompatibleClient` instance
- **THEN** no HTTP request is sent and the call completes successfully

### Requirement: Ollama client releases the loaded model on request
The `OllamaClient` SHALL override `releaseResources()` to ask the configured Ollama server to unload the configured model immediately. The implementation SHALL send a single HTTP `POST` to `{baseUrl}/api/generate` with a JSON body containing the configured model name, `"keep_alive": 0`, and `"stream": false`, and without a `prompt` field, so that the server unloads the model without performing any generation and returns a single non-streamed JSON response. Transport-level or server-side errors SHALL be propagated to the caller as exceptions following standard Dart conventions; suppression of such errors is the caller's responsibility (see the `llm-summary-pipeline` capability).

#### Scenario: Releasing resources sends an unload request to Ollama
- **WHEN** `releaseResources()` is invoked on an `OllamaClient` configured with `baseUrl = "http://localhost:11434"` and `model = "llama3"`
- **THEN** the client sends a single HTTP `POST` to `http://localhost:11434/api/generate` with a JSON body equivalent to `{"model": "llama3", "keep_alive": 0, "stream": false}` (no `prompt` field), and the call completes successfully when the server responds with status 200

#### Scenario: Non-success response surfaces as an exception
- **WHEN** the Ollama server responds to the unload request with a non-success status code (e.g., 500)
- **THEN** `releaseResources()` throws an exception so that the caller can decide whether to log or swallow it

#### Scenario: Network failure surfaces as an exception
- **WHEN** the underlying HTTP client raises an I/O error during the unload request
- **THEN** `releaseResources()` propagates the exception to the caller
