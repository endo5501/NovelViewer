## ADDED Requirements

### Requirement: LLM provider selection in settings
The settings dialog SHALL include an LLM configuration section where the user can select between "OpenAI互換API" and "Ollama" as the LLM provider. The LLM configuration section SHALL be accessible via scrolling when the settings dialog content exceeds the visible area.

#### Scenario: Display LLM provider dropdown
- **WHEN** the user opens the settings dialog
- **THEN** an LLM provider dropdown is displayed with options "OpenAI互換API" and "Ollama", plus a "未設定" (not configured) default option

#### Scenario: Select OpenAI-compatible provider
- **WHEN** the user selects "OpenAI互換API" from the provider dropdown
- **THEN** the OpenAI-specific configuration fields (endpoint URL, API key, model name) are displayed

#### Scenario: Select Ollama provider
- **WHEN** the user selects "Ollama" from the provider dropdown
- **THEN** the Ollama-specific configuration fields (endpoint URL, model name) are displayed

#### Scenario: LLM dropdown accessible via scrolling
- **WHEN** the settings dialog contains more content than the visible area
- **THEN** the user SHALL be able to scroll to the LLM provider dropdown and interact with it

### Requirement: OpenAI-compatible API configuration
The system SHALL allow the user to configure OpenAI-compatible API connection settings: endpoint URL, API key, and model name. The API key SHALL be stored in the OS-provided secure storage (`flutter_secure_storage`); other fields SHALL be stored in `SharedPreferences`.

#### Scenario: Configure OpenAI endpoint URL
- **WHEN** the user enters "https://api.openai.com/v1" in the endpoint URL field
- **THEN** the value is persisted in `SharedPreferences` and used for subsequent LLM requests

#### Scenario: Configure OpenAI API key
- **WHEN** the user enters an API key in the API key field
- **THEN** the value is persisted in `flutter_secure_storage` (not in `SharedPreferences`) and used as Bearer token in Authorization header for LLM requests

#### Scenario: Configure OpenAI model name
- **WHEN** the user enters "gpt-4o-mini" in the model name field
- **THEN** the value is persisted in `SharedPreferences` and used as the model parameter in LLM requests

#### Scenario: Clearing the API key
- **WHEN** the user clears the API key field (empty string)
- **THEN** the system removes the API key entry from `flutter_secure_storage`

### Requirement: Ollama configuration
The system SHALL allow the user to configure Ollama connection settings: endpoint URL and model name. The endpoint URL SHALL default to "http://localhost:11434". The model name SHALL be selected from a dropdown populated by fetching the installed model list from the Ollama server, instead of manual text input.

#### Scenario: Configure Ollama with default URL
- **WHEN** the user selects Ollama and does not modify the endpoint URL
- **THEN** the default URL "http://localhost:11434" is used for LLM requests

#### Scenario: Configure Ollama custom URL
- **WHEN** the user enters "http://192.168.1.100:11434" as the Ollama endpoint URL
- **THEN** the value is persisted and used for subsequent LLM requests

#### Scenario: Configure Ollama model via dropdown
- **WHEN** the user selects a model name from the Ollama model dropdown
- **THEN** the value is persisted and used as the model parameter in LLM requests

### Requirement: LLM settings persistence
Non-secret LLM configuration settings (provider selection, endpoint URLs, model names) SHALL be persisted using `SharedPreferences`. The OpenAI-compatible API key SHALL be persisted using `flutter_secure_storage`. Both stores SHALL be restored when the application starts.

#### Scenario: Settings persist across app restarts
- **WHEN** the user configures LLM settings and restarts the application
- **THEN** the previously configured LLM provider, endpoint URL, and model name are restored from `SharedPreferences` and the API key is restored from `flutter_secure_storage`

#### Scenario: Default state with no configuration
- **WHEN** the application starts for the first time with no LLM settings saved
- **THEN** the LLM provider is "未設定" (not configured) and no LLM features are available

#### Scenario: API key never written to SharedPreferences after migration
- **WHEN** the user enters a new API key after the migration has run
- **THEN** the value is written only to `flutter_secure_storage` and `SharedPreferences` contains no `llm_api_key` entry

### Requirement: LLM client creation from settings
The system SHALL create the appropriate LLM client (`OllamaClient` or `OpenAiCompatibleClient`) based on the current settings. The OpenAI-compatible client SHALL load the API key from `flutter_secure_storage` on demand at client creation time, not from a long-lived `LlmConfig` value object.

#### Scenario: Create Ollama client from settings
- **WHEN** the LLM provider is set to "Ollama" with URL "http://localhost:11434" and model "llama3"
- **THEN** the system creates an `OllamaClient` configured with the specified URL and model

#### Scenario: Create OpenAI client from settings
- **WHEN** the LLM provider is set to "OpenAI互換API" with URL and model configured, and an API key exists in `flutter_secure_storage`
- **THEN** the system reads the API key from `flutter_secure_storage` at client creation time and creates an `OpenAiCompatibleClient` configured with the specified parameters

#### Scenario: Return null client when not configured
- **WHEN** the LLM provider is "未設定"
- **THEN** the system returns null for the LLM client, indicating LLM features are unavailable

#### Scenario: Return null client when API key missing
- **WHEN** the LLM provider is "OpenAI互換API" and `flutter_secure_storage` has no API key entry
- **THEN** the system returns null for the LLM client, indicating LLM features are unavailable

### Requirement: API key migration from SharedPreferences to secure storage
On application startup, the system SHALL migrate any pre-existing `llm_api_key` entry in `SharedPreferences` to `flutter_secure_storage`. The migration SHALL be idempotent (safe to run on every startup), SHALL NOT block app startup if it fails, and SHALL leave the source `SharedPreferences` entry intact when the destination write fails so that the migration is retried on the next startup.

#### Scenario: Existing user with API key in SharedPreferences
- **WHEN** the application starts and `SharedPreferences` contains an `llm_api_key` entry
- **THEN** the system writes that key to `flutter_secure_storage`, then deletes the entry from `SharedPreferences`, and the user is not prompted to re-enter the key

#### Scenario: New user without prior API key
- **WHEN** the application starts and `SharedPreferences` contains no `llm_api_key` entry
- **THEN** the migration is a no-op and startup proceeds normally

#### Scenario: Migration runs idempotently on each startup
- **WHEN** the migration has already completed and the application starts again
- **THEN** the migration detects no `llm_api_key` entry in `SharedPreferences` and exits without touching `flutter_secure_storage`

#### Scenario: Secure storage write failure is non-fatal
- **WHEN** writing to `flutter_secure_storage` throws (e.g. `libsecret` unavailable on Linux)
- **THEN** the system logs the failure via `debugPrint`, leaves the `SharedPreferences` entry untouched, and continues normal startup so the migration is retried next time

#### Scenario: Migration completes before any LLM client is constructed
- **WHEN** the application creates an `OpenAiCompatibleClient` after startup
- **THEN** the migration has already executed, so the client reads from `flutter_secure_storage` and finds the migrated key

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
