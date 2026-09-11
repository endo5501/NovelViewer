## MODIFIED Requirements

### Requirement: LLM provider selection in settings
The settings dialog SHALL include an LLM configuration section where the user can select between "OpenAI互換API" and "Ollama" as the LLM provider, on platforms where LLM summary is available. The LLM configuration section SHALL be accessible via scrolling when the settings dialog content exceeds the visible area. Where LLM summary is unavailable, the section SHALL be absent from the dialog rather than shown in a state that cannot reach a server, since no configuration entered there could be acted on.

The reason a platform may report the feature as unavailable belongs to the capability model, not to this section. In particular the transport policy is not such a reason: the HTTP client the requests are sent through opens its own sockets and is not subject to it. Where the feature is available, the section SHALL be shown whether or not the reader has a server within reach — the default endpoint addresses the machine the app runs on, which on a tablet is not where the server lives, and the section is how the reader points it somewhere else.

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

#### Scenario: The section is present on a tablet
- **WHEN** the user opens the settings dialog on iOS
- **THEN** the LLM configuration section is present, with the same provider options it offers on a desktop platform
