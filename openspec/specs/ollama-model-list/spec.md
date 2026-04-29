### Requirement: Fetch Ollama model list from server
The system SHALL fetch the list of installed models from the Ollama server by calling `GET {baseUrl}/api/tags`. The response SHALL be parsed to extract model names from the `models` array.

#### Scenario: Successfully fetch model list
- **WHEN** the system calls `GET http://localhost:11434/api/tags` and the server responds with a JSON containing a `models` array
- **THEN** the system returns a list of model name strings extracted from each model's `name` field

#### Scenario: Server is not running
- **WHEN** the system calls `GET http://localhost:11434/api/tags` and the connection fails
- **THEN** the system throws an exception indicating the connection failure

#### Scenario: Server returns error status
- **WHEN** the system calls `GET http://localhost:11434/api/tags` and the server responds with a non-200 status code
- **THEN** the system throws an exception containing the status code and response body

#### Scenario: Server returns empty model list
- **WHEN** the system calls `GET http://localhost:11434/api/tags` and the server responds with `{"models": []}`
- **THEN** the system returns an empty list

### Requirement: Display Ollama model dropdown in settings
The settings dialog SHALL display a dropdown for Ollama model selection instead of a text input field when the Ollama provider is selected. The dropdown's data source SHALL be a Riverpod `FutureProvider.family<List<String>, String>` keyed by the Ollama base URL (`ollamaModelListProvider`); the section SHALL consume this provider via `ref.watch` and render UI states (data / loading / error) directly from the resulting `AsyncValue`. The section SHALL NOT maintain ad-hoc booleans or fetch-generation counters in widget state for tracking the fetch lifecycle.

#### Scenario: Show model dropdown with fetched models
- **WHEN** the user selects Ollama as the LLM provider and the model list is successfully fetched
- **THEN** a dropdown is displayed containing the fetched model names sourced from `ollamaModelListProvider(currentBaseUrl).when(data: (list) => list, ...)`

#### Scenario: Auto-fetch models on Ollama selection
- **WHEN** the user selects Ollama as the LLM provider
- **THEN** `ref.watch(ollamaModelListProvider(currentBaseUrl))` triggers the underlying fetch automatically; no imperative fetch call from widget code is required

#### Scenario: Show loading state while fetching
- **WHEN** the model list is being fetched from the Ollama server
- **THEN** the section renders a loading indicator via `AsyncValue.loading` (no widget-state `_isLoading` boolean is required)

#### Scenario: Show error when fetch fails
- **WHEN** the model list fetch fails due to connection error or server error
- **THEN** the section renders the error message via `AsyncValue.error` (no widget-state `_error` field is required)

#### Scenario: Refresh model list with button
- **WHEN** the user clicks the refresh button next to the model dropdown
- **THEN** the section calls `ref.invalidate(ollamaModelListProvider(currentBaseUrl))`, which causes the provider to re-execute and emit a new `AsyncValue.loading` followed by `AsyncValue.data` or `AsyncValue.error`

#### Scenario: URL change cancels stale fetch
- **WHEN** the user edits the Ollama base URL while a fetch is in flight for the previous URL
- **THEN** the in-flight fetch for the old URL is auto-disposed via `FutureProvider.autoDispose`, and a fresh fetch starts for the new URL; no manual generation counter is needed

#### Scenario: Restore saved model selection
- **WHEN** the settings dialog is opened and the saved LLM provider is Ollama with a previously selected model
- **THEN** the dropdown shows the saved model as the selected value once `ollamaModelListProvider` resolves to data and the saved model is in the list

#### Scenario: Saved model no longer available
- **WHEN** the settings dialog is opened and the previously saved model name is not in the fetched model list
- **THEN** the saved model selection is cleared
