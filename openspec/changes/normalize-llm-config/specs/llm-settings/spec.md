## MODIFIED Requirements

### Requirement: LLM settings persistence
Non-secret LLM configuration settings (provider selection, endpoint URLs, model names) SHALL be persisted using `SharedPreferences`. The OpenAI-compatible API key SHALL be persisted using `flutter_secure_storage`. Both stores SHALL be restored when the application starts.

Text-valued LLM settings SHALL be normalized both when written to and when read from their store, so that a value saved before this rule existed is corrected without a migration step:

- The endpoint URL SHALL have leading and trailing whitespace removed, and SHALL have every trailing `/` removed.
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
