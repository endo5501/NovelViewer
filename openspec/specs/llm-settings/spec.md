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
The system SHALL allow the user to configure OpenAI-compatible API connection settings: endpoint URL, API key, and model name.

#### Scenario: Configure OpenAI endpoint URL
- **WHEN** the user enters "https://api.openai.com/v1" in the endpoint URL field
- **THEN** the value is persisted and used for subsequent LLM requests

#### Scenario: Configure OpenAI API key
- **WHEN** the user enters an API key in the API key field
- **THEN** the value is persisted and used as Bearer token in Authorization header for LLM requests

#### Scenario: Configure OpenAI model name
- **WHEN** the user enters "gpt-4o-mini" in the model name field
- **THEN** the value is persisted and used as the model parameter in LLM requests

### Requirement: Ollama configuration
The system SHALL allow the user to configure Ollama connection settings: endpoint URL and model name. The endpoint URL SHALL default to "http://localhost:11434".

#### Scenario: Configure Ollama with default URL
- **WHEN** the user selects Ollama and does not modify the endpoint URL
- **THEN** the default URL "http://localhost:11434" is used for LLM requests

#### Scenario: Configure Ollama custom URL
- **WHEN** the user enters "http://192.168.1.100:11434" as the Ollama endpoint URL
- **THEN** the value is persisted and used for subsequent LLM requests

#### Scenario: Configure Ollama model name
- **WHEN** the user enters a model name in the Ollama model field
- **THEN** the value is persisted and used as the model parameter in LLM requests

### Requirement: LLM settings persistence
All LLM configuration settings SHALL be persisted using SharedPreferences and restored when the application starts.

#### Scenario: Settings persist across app restarts
- **WHEN** the user configures LLM settings and restarts the application
- **THEN** the previously configured LLM provider, endpoint URL, API key, and model name are restored

#### Scenario: Default state with no configuration
- **WHEN** the application starts for the first time with no LLM settings saved
- **THEN** the LLM provider is "未設定" (not configured) and no LLM features are available

### Requirement: LLM client creation from settings
The system SHALL create the appropriate LLM client (OllamaClient or OpenAiCompatibleClient) based on the current settings.

#### Scenario: Create Ollama client from settings
- **WHEN** the LLM provider is set to "Ollama" with URL "http://localhost:11434" and model "llama3"
- **THEN** the system creates an OllamaClient configured with the specified URL and model

#### Scenario: Create OpenAI client from settings
- **WHEN** the LLM provider is set to "OpenAI互換API" with URL, API key, and model configured
- **THEN** the system creates an OpenAiCompatibleClient configured with the specified parameters

#### Scenario: Return null client when not configured
- **WHEN** the LLM provider is "未設定"
- **THEN** the system returns null for the LLM client, indicating LLM features are unavailable
