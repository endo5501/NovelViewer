## ADDED Requirements

### Requirement: Incomplete LLM configuration names the missing setting
When analysis cannot start because the selected provider's configuration is incomplete, the system SHALL tell the reader which setting is missing rather than asking them to configure an LLM they have already selected.

The message SHALL be chosen from the same decision that stopped the client from being created, so the wording cannot disagree with the reason.

| Situation | Message |
|---|---|
| No provider selected | the existing "設定画面でLLMを設定してください" |
| Endpoint URL missing | names the endpoint URL |
| Model name missing | names the model name |
| API key missing | names the API key |

These messages SHALL be shown with the ordinary snackbar, NOT the persistent failure snackbar with its details action. A configuration message carries no exception and no stack trace, so the diagnostic dialog would add nothing, and the message is short enough to read within the ordinary display time.

Every message SHALL be localized in Japanese, English and Chinese.

The on-device provider SHALL keep its own availability messages, which describe why the model cannot be used rather than which setting is missing.

#### Scenario: Only the API key is missing
- **WHEN** the reader triggers analysis with the OpenAI-compatible provider selected, an endpoint URL and a model name configured, and no API key stored
- **THEN** the snackbar SHALL name the API key as the missing setting
- **AND** it SHALL NOT read "設定画面でLLMを設定してください"

#### Scenario: Only the endpoint URL is missing
- **WHEN** the reader triggers analysis with the Ollama provider selected, a model name configured, and an empty endpoint URL
- **THEN** the snackbar SHALL name the endpoint URL as the missing setting

#### Scenario: Only the model name is missing
- **WHEN** the reader triggers analysis with the Ollama provider selected, an endpoint URL configured, and an empty model name
- **THEN** the snackbar SHALL name the model name as the missing setting

#### Scenario: No provider is selected
- **WHEN** the reader triggers analysis with no LLM provider selected
- **THEN** the snackbar SHALL read the existing "設定画面でLLMを設定してください"

#### Scenario: An endpoint URL of only whitespace counts as missing
- **WHEN** the stored endpoint URL consists only of whitespace and the reader triggers analysis
- **THEN** the snackbar SHALL name the endpoint URL as the missing setting
- **AND** no request SHALL be sent, so no `FormatException` reaches the reader

#### Scenario: The configuration message uses the ordinary snackbar
- **WHEN** any of these configuration messages is shown
- **THEN** the snackbar SHALL carry no details action and SHALL dismiss on its own
- **AND** no failure detail dialog SHALL be reachable from it

#### Scenario: The on-device provider keeps its availability messages
- **WHEN** the reader triggers analysis with the on-device provider selected and the model unavailable
- **THEN** the snackbar SHALL state why the model cannot be used, unchanged by this requirement
