## MODIFIED Requirements

### Requirement: LLM provider selection in settings
The settings dialog SHALL include an LLM configuration section where the user can select between "OpenAI互換API" and "Ollama" as the LLM provider, on platforms where LLM summary is available. The LLM configuration section SHALL be accessible via scrolling when the settings dialog content exceeds the visible area. Where LLM summary is unavailable, the section SHALL be absent from the dialog rather than shown in a state that cannot reach a server: the platform's transport policy blocks the plaintext HTTP endpoint the section defaults to, so any configuration entered there could only fail.

#### Scenario: Display LLM provider dropdown
- **WHEN** the user opens the settings dialog on a platform where LLM summary is available
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

#### Scenario: The section is absent where LLM summary is unavailable
- **WHEN** the user opens the settings dialog on a platform where LLM summary is unavailable
- **THEN** the general tab contains no LLM configuration section, and its remaining sections render in their usual order without a dangling separator
