## Purpose

LLM provider configuration (OpenAI-compatible API or Ollama): in-app settings UI, persistence (SharedPreferences for non-secrets, flutter_secure_storage for API keys), startup migration from legacy plaintext storage, client construction, and a `releaseResources()` contract for unloading model state.

## Requirements

### Requirement: LLM provider selection in settings
The settings dialog SHALL include an LLM configuration section where the user can select between "OpenAI互換API", "Ollama" and the on-device model as the LLM provider, on platforms where LLM summary is available. The LLM configuration section SHALL be accessible via scrolling when the settings dialog content exceeds the visible area. Where LLM summary is unavailable, the section SHALL be absent from the dialog rather than shown in a state that cannot reach a server, since no configuration entered there could be acted on.

The reason a platform may report the feature as unavailable belongs to the capability model, not to this section. In particular the transport policy is not such a reason: the HTTP client the requests are sent through opens its own sockets and is not subject to it. Where the feature is available, the section SHALL be shown whether or not the reader has a server within reach — the default endpoint addresses the machine the app runs on, which on a tablet is not where the server lives, and the section is how the reader points it somewhere else.

Whether the on-device option appears at all, whether it can be selected, and what reason accompanies it are governed by `apple-on-device-llm`: the platform being able to host the model is necessary but not sufficient, since an operating system without the framework and a device that cannot run it are both answered by the native side rather than by a platform flag. Selecting it SHALL reveal no configuration fields: it addresses no endpoint, carries no credential and names no model. The section SHALL therefore show, for that provider, only the selection itself and whatever reason applies.

#### Scenario: Display LLM provider dropdown
- **WHEN** the user opens the settings dialog on a platform where LLM summary is available
- **THEN** an LLM provider dropdown is displayed with options "OpenAI互換API" and "Ollama", plus a "未設定" (not configured) default option

#### Scenario: Select OpenAI-compatible provider
- **WHEN** the user selects "OpenAI互換API" from the provider dropdown
- **THEN** the OpenAI-specific configuration fields (endpoint URL, API key, model name) are displayed

#### Scenario: Select Ollama provider
- **WHEN** the user selects "Ollama" from the provider dropdown
- **THEN** the Ollama-specific configuration fields (endpoint URL, model name) are displayed

#### Scenario: The on-device option appears where the model is usable
- **WHEN** the user opens the settings dialog on a platform that can host the on-device model, with the model reported available
- **THEN** the provider dropdown SHALL offer the on-device option alongside the two server-backed options

#### Scenario: Selecting the on-device provider reveals no configuration fields
- **WHEN** the user selects the on-device provider
- **THEN** no endpoint URL field, no API key field and no model name field SHALL be displayed

#### Scenario: LLM dropdown accessible via scrolling
- **WHEN** the settings dialog contains more content than the visible area
- **THEN** the user SHALL be able to scroll to the LLM provider dropdown and interact with it

#### Scenario: The section is absent where LLM summary is unavailable
- **WHEN** the user opens the settings dialog on a platform where LLM summary is unavailable
- **THEN** the general tab contains no LLM configuration section, and its remaining sections render in their usual order without a dangling separator

#### Scenario: The section is present on a tablet
- **WHEN** the user opens the settings dialog on iOS
- **THEN** the LLM configuration section is present, with the same provider options it offers on a desktop platform

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

The model list SHALL be fetched from the normalized endpoint URL, so that whitespace still sitting in the settings field does not leave the dropdown empty and the reader with no model to select.

#### Scenario: Configure Ollama with default URL
- **WHEN** the user selects Ollama and does not modify the endpoint URL
- **THEN** the default URL "http://localhost:11434" is used for LLM requests

#### Scenario: Configure Ollama custom URL
- **WHEN** the user enters "http://192.168.1.100:11434" as the Ollama endpoint URL
- **THEN** the value is persisted and used for subsequent LLM requests

#### Scenario: Configure Ollama model via dropdown
- **WHEN** the user selects a model name from the Ollama model dropdown
- **THEN** the value is persisted and used as the model parameter in LLM requests

#### Scenario: A pasted endpoint URL still populates the model dropdown
- **WHEN** the user pastes `" http://localhost:11434/ "` into the endpoint URL field
- **THEN** the model list SHALL be fetched from `http://localhost:11434`
- **AND** the dropdown SHALL list the models the server reports, rather than a fetch error

### Requirement: LLM settings persistence
Non-secret LLM configuration settings (provider selection, endpoint URLs, model names) SHALL be persisted using `SharedPreferences`. The OpenAI-compatible API key SHALL be persisted using `flutter_secure_storage`. Both stores SHALL be restored when the application starts.

Text-valued LLM settings SHALL be normalized both when written to and when read from their store, so that a value saved before this rule existed is corrected without a migration step:

- The endpoint URL SHALL have leading and trailing whitespace removed, and SHALL have every trailing `/` removed. Where the value carries a query or a fragment, the trailing `/` SHALL be left in place, because there the last character belongs to data the application does not interpret.
- The model name SHALL have leading and trailing whitespace removed.
- The API key SHALL have leading and trailing whitespace removed.

Normalization SHALL NOT alter characters inside a value, and SHALL NOT be written back into the settings screen's text controllers while the user is editing.

#### Scenario: Settings persist across app restarts
- **WHEN** the user configures LLM settings and restarts the application
- **THEN** the previously configured LLM provider, endpoint URL, and model name are restored from `SharedPreferences` and the API key is restored from `flutter_secure_storage`

#### Scenario: Default state with no configuration
- **WHEN** the application starts for the first time with no LLM settings saved
- **THEN** the LLM provider is "未設定" (not configured) and no LLM features are available

#### Scenario: API key never written to SharedPreferences after migration
- **WHEN** the user enters a new API key after the migration has run
- **THEN** the value is written only to `flutter_secure_storage` and `SharedPreferences` contains no `llm_api_key` entry

#### Scenario: Surrounding whitespace is stripped from the endpoint URL on save
- **WHEN** the user saves an LLM configuration whose endpoint URL is `" http://localhost:11434 "`
- **THEN** `SharedPreferences` holds `http://localhost:11434`

#### Scenario: Trailing slashes are stripped from the endpoint URL
- **WHEN** the user saves an LLM configuration whose endpoint URL is `"https://api.example.com/v1//"`
- **THEN** `SharedPreferences` holds `https://api.example.com/v1`

#### Scenario: A trailing slash inside a query string is preserved
- **WHEN** the user saves an LLM configuration whose endpoint URL is `"https://host/proxy?route=/v1/"`
- **THEN** reading the LLM configuration yields that value unchanged

#### Scenario: A trailing slash inside a fragment is preserved
- **WHEN** the user saves an LLM configuration whose endpoint URL is `"https://host/base#section/"`
- **THEN** reading the LLM configuration yields that value unchanged

#### Scenario: An endpoint URL saved before normalization existed is corrected on read
- **WHEN** `SharedPreferences` already holds `" http://localhost:11434/ "` from an earlier version
- **THEN** reading the LLM configuration yields the endpoint URL `http://localhost:11434`

#### Scenario: Surrounding whitespace is stripped from the model name
- **WHEN** the user saves an LLM configuration whose model name is `"  llama3\n"`
- **THEN** reading the LLM configuration yields the model name `llama3`

#### Scenario: A slash inside the model name is preserved
- **WHEN** the user saves an LLM configuration whose model name is `"org/model"`
- **THEN** reading the LLM configuration yields the model name `org/model` unchanged

#### Scenario: Surrounding whitespace is stripped from the API key
- **WHEN** the user pastes an API key as `"sk-example\n"` and it is saved
- **THEN** `flutter_secure_storage` holds `sk-example`, so the `Authorization` header carries no line break

#### Scenario: A value that is only whitespace becomes empty
- **WHEN** the user saves an LLM configuration whose endpoint URL is `"   "`
- **THEN** reading the LLM configuration yields an empty endpoint URL

### Requirement: LLM client creation from settings
The system SHALL create the appropriate LLM client (`OllamaClient`, `OpenAiCompatibleClient`, or the on-device client) based on the current settings. The OpenAI-compatible client SHALL load the API key from `flutter_secure_storage` on demand at client creation time, not from a long-lived `LlmConfig` value object.

Where the selected provider is the on-device model and that model is not available, the system SHALL return null for the LLM client rather than creating a client for a different provider. Falling back is forbidden by `apple-on-device-llm`, and the stored selection SHALL be left as the reader set it.

Where the selected provider is addressed by server settings, the system SHALL determine whether the configuration is complete before creating a client, and SHALL return null when any required setting is missing. The required settings are the endpoint URL and the model name for Ollama, and the endpoint URL, the model name and the API key for the OpenAI-compatible API. This determination SHALL be made by a single shared decision so that the reason a client was not created is the same reason reported to the reader.

Where more than one required setting is missing, the reported reason SHALL name exactly one, chosen in the order endpoint URL, model name, API key.

#### Scenario: Create Ollama client from settings
- **WHEN** the LLM provider is set to "Ollama" with URL "http://localhost:11434" and model "llama3"
- **THEN** the system creates an `OllamaClient` configured with the specified URL and model

#### Scenario: Create OpenAI client from settings
- **WHEN** the LLM provider is set to "OpenAI互換API" with URL and model configured, and an API key exists in `flutter_secure_storage`
- **THEN** the system reads the API key from `flutter_secure_storage` at client creation time and creates an `OpenAiCompatibleClient` configured with the specified parameters

#### Scenario: Create the on-device client from settings
- **WHEN** the LLM provider is set to the on-device model and that model is available
- **THEN** the system creates the on-device client, which needs no endpoint, credential or model name

#### Scenario: Return null client when the on-device model is unavailable
- **WHEN** the LLM provider is set to the on-device model and that model is unavailable
- **THEN** the system returns null for the LLM client
- **AND** it SHALL NOT create an `OllamaClient` or an `OpenAiCompatibleClient` from any previously stored server settings

#### Scenario: Return null client when not configured
- **WHEN** the LLM provider is "未設定"
- **THEN** the system returns null for the LLM client, indicating LLM features are unavailable

#### Scenario: Return null client when API key missing
- **WHEN** the LLM provider is "OpenAI互換API" and `flutter_secure_storage` has no API key entry
- **THEN** the system returns null for the LLM client, indicating LLM features are unavailable

#### Scenario: Return null client when the endpoint URL is missing
- **WHEN** the LLM provider is "Ollama" or "OpenAI互換API" and the stored endpoint URL is empty
- **THEN** the system returns null for the LLM client
- **AND** no HTTP request SHALL be attempted

#### Scenario: Return null client when the model name is missing
- **WHEN** the LLM provider is "Ollama" or "OpenAI互換API" with an endpoint URL configured and an empty model name
- **THEN** the system returns null for the LLM client
- **AND** no HTTP request SHALL be attempted

#### Scenario: The on-device provider is never judged by server settings
- **WHEN** the LLM provider is set to the on-device model, that model is available, and no endpoint URL, model name or API key is stored
- **THEN** the system creates the on-device client

#### Scenario: The missing setting reported first is the endpoint URL
- **WHEN** the LLM provider is "OpenAI互換API" and the endpoint URL, the model name and the API key are all empty
- **THEN** the reported reason names the endpoint URL
### Requirement: API key migration from SharedPreferences to secure storage
On application startup, the system SHALL migrate any pre-existing `llm_api_key` entry in `SharedPreferences` to `flutter_secure_storage`. The migration SHALL be idempotent (safe to run on every startup), SHALL NOT block app startup if it fails, and SHALL leave the source `SharedPreferences` entry intact when the destination write fails so that the migration is retried on the next startup. When the migration fails, the system SHALL record the failure through the AppLogger pipeline (`logging-infrastructure`) at `WARNING` level — not via `debugPrint` only — so that the failure leaves a trace in release builds (where a user may still have a plaintext API key in `SharedPreferences`).

#### Scenario: Existing user with API key in SharedPreferences
- **WHEN** the application starts and `SharedPreferences` contains an `llm_api_key` entry
- **THEN** the system writes that key to `flutter_secure_storage`, then deletes the entry from `SharedPreferences`, and the user is not prompted to re-enter the key

#### Scenario: New user without prior API key
- **WHEN** the application starts and `SharedPreferences` contains no `llm_api_key` entry
- **THEN** the migration is a no-op and startup proceeds normally

#### Scenario: Migration runs idempotently on each startup
- **WHEN** the migration has already completed and the application starts again
- **THEN** the migration detects no `llm_api_key` entry in `SharedPreferences` and exits without touching `flutter_secure_storage`

#### Scenario: Secure storage write failure is non-fatal and logged via AppLogger
- **WHEN** writing to `flutter_secure_storage` throws (e.g. `libsecret` unavailable on Linux)
- **THEN** the system records the failure via the AppLogger pipeline at `WARNING` level (not `debugPrint` only), leaves the `SharedPreferences` entry untouched, and continues normal startup so the migration is retried next time

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
