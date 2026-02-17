## MODIFIED Requirements

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
