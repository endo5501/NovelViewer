## MODIFIED Requirements

### Requirement: LLM provider selection in settings
The settings dialog SHALL include an LLM configuration section where the user can select between "OpenAI互換API", "Ollama" and the on-device model as the LLM provider, on platforms where LLM summary is available. The LLM configuration section SHALL be accessible via scrolling when the settings dialog content exceeds the visible area. Where LLM summary is unavailable, the section SHALL be absent from the dialog rather than shown in a state that cannot reach a server, since no configuration entered there could be acted on.

The reason a platform may report the feature as unavailable belongs to the capability model, not to this section. In particular the transport policy is not such a reason: the HTTP client the requests are sent through opens its own sockets and is not subject to it. Where the feature is available, the section SHALL be shown whether or not the reader has a server within reach — the default endpoint addresses the machine the app runs on, which on a tablet is not where the server lives, and the section is how the reader points it somewhere else.

The on-device option SHALL be offered only where the platform can host the model at all, and its selectability and accompanying reason are governed by `apple-on-device-llm`. Selecting it SHALL reveal no configuration fields: it addresses no endpoint, carries no credential and names no model. The section SHALL therefore show, for that provider, only the selection itself and whatever reason applies.

#### Scenario: Display LLM provider dropdown
- **WHEN** the user opens the settings dialog on a platform where LLM summary is available
- **THEN** an LLM provider dropdown is displayed with options "OpenAI互換API" and "Ollama", plus a "未設定" (not configured) default option

#### Scenario: Select OpenAI-compatible provider
- **WHEN** the user selects "OpenAI互換API" from the provider dropdown
- **THEN** the OpenAI-specific configuration fields (endpoint URL, API key, model name) are displayed

#### Scenario: Select Ollama provider
- **WHEN** the user selects "Ollama" from the provider dropdown
- **THEN** the Ollama-specific configuration fields (endpoint URL, model name) are displayed

#### Scenario: The on-device option appears where the platform can host the model
- **WHEN** the user opens the settings dialog on a platform that can host the on-device model
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

### Requirement: LLM client creation from settings
The system SHALL create the appropriate LLM client (`OllamaClient`, `OpenAiCompatibleClient`, or the on-device client) based on the current settings. The OpenAI-compatible client SHALL load the API key from `flutter_secure_storage` on demand at client creation time, not from a long-lived `LlmConfig` value object.

Where the selected provider is the on-device model and that model is not available, the system SHALL return null for the LLM client rather than creating a client for a different provider. Falling back is forbidden by `apple-on-device-llm`, and the stored selection SHALL be left as the reader set it.

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
