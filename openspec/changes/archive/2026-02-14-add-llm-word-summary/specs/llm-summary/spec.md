## ADDED Requirements

### Requirement: LLM summary panel with spoiler tabs
The system SHALL display an LLM summary panel in the upper section of the right column with two tabs: "ネタバレなし" (no spoiler) and "ネタバレあり" (spoiler).

#### Scenario: Display two tabs in the summary panel
- **WHEN** the LLM summary panel is rendered
- **THEN** a TabBar with "ネタバレなし" and "ネタバレあり" tabs is displayed, with "ネタバレなし" selected by default

#### Scenario: Switch between spoiler tabs
- **WHEN** the user clicks the "ネタバレあり" tab
- **THEN** the tab view switches to show the spoiler summary content

### Requirement: Analysis start button
Each tab SHALL contain an "解析開始" button that triggers LLM analysis when pressed.

#### Scenario: Display analysis button when word is selected
- **WHEN** the user has selected a word in the text viewer and no cached summary exists
- **THEN** the "解析開始" button is displayed in the active tab

#### Scenario: Display analysis button alongside cached result
- **WHEN** the user has selected a word and a cached summary exists
- **THEN** both the cached summary text and the "解析開始" button are displayed, allowing re-analysis

#### Scenario: Trigger analysis on button press
- **WHEN** the user presses the "解析開始" button
- **THEN** the system sends a request to the configured LLM with the constructed prompt and displays a loading indicator

### Requirement: Spoiler summary uses all files
The "ネタバレあり" summary SHALL use search results from all text files in the document folder as context for LLM analysis.

#### Scenario: Generate spoiler summary from all files
- **WHEN** the user triggers analysis on the "ネタバレあり" tab for the word "アリス"
- **THEN** the system searches all text files in the current directory for "アリス", collects surrounding context from all matches, and sends them to the LLM for summarization

### Requirement: No-spoiler summary uses files up to current position
The "ネタバレなし" summary SHALL use search results only from text files up to and including the currently viewed file, based on numeric filename prefix ordering.

#### Scenario: Generate no-spoiler summary limited to current file position
- **WHEN** the user is viewing file "040_chapter.txt" and triggers analysis on the "ネタバレなし" tab for the word "アリス"
- **THEN** the system searches only files with numeric prefix <= 40 (e.g., "001_chapter.txt" through "040_chapter.txt") and uses only those results as context for LLM summarization

#### Scenario: No-spoiler excludes later files
- **WHEN** the user is viewing file "040_chapter.txt" and files "050_chapter.txt" and "060_chapter.txt" also contain the search term
- **THEN** those later files are excluded from the context sent to the LLM

### Requirement: LLM summary display states
The LLM summary panel SHALL display appropriate content based on the current state.

#### Scenario: No word selected
- **WHEN** no text is selected in the text viewer
- **THEN** the panel displays a message "単語を選択してください"

#### Scenario: LLM not configured
- **WHEN** a word is selected but no LLM provider is configured in settings
- **THEN** the panel displays a message "設定画面でLLMを設定してください"

#### Scenario: Analysis in progress
- **WHEN** LLM analysis is in progress
- **THEN** the panel displays a loading indicator and the "解析開始" button is disabled

#### Scenario: Analysis completed successfully
- **WHEN** LLM analysis completes successfully
- **THEN** the panel displays the summary text and the "解析開始" button is re-enabled for re-analysis

#### Scenario: Analysis failed with error
- **WHEN** LLM analysis fails (network error, API error, etc.)
- **THEN** the panel displays an error message and the "解析開始" button is re-enabled for retry

### Requirement: Prompt construction for word summary
The system SHALL construct LLM prompts using XML-tagged structure with the selected word and surrounding context from search results.

#### Scenario: Build prompt with search context
- **WHEN** the system builds a prompt for the word "聖印" with 3 matching contexts found
- **THEN** the prompt includes the word wrapped in a `<term>` tag and the context texts wrapped in a `<context>` tag, requesting a JSON response with a "summary" field

#### Scenario: Build no-spoiler prompt with restriction
- **WHEN** the system builds a no-spoiler prompt
- **THEN** the prompt includes an additional instruction to explain based only on the provided context without including future plot developments

#### Scenario: Limit context to maximum entries
- **WHEN** search results yield more than 10 matching contexts
- **THEN** the prompt includes at most 10 context entries to stay within LLM token limits

### Requirement: LLM response parsing
The system SHALL parse the LLM response as JSON to extract the summary text.

#### Scenario: Parse valid JSON response
- **WHEN** the LLM returns `{"summary": "聖印とは騎士に与えられる神聖な印章である。"}`
- **THEN** the system extracts and displays "聖印とは騎士に与えられる神聖な印章である。"

#### Scenario: Handle non-JSON response gracefully
- **WHEN** the LLM returns a plain text response instead of JSON
- **THEN** the system uses the raw response text as the summary

### Requirement: Summary reacts to selected text changes
The LLM summary panel SHALL watch the selected text provider and update its display when a new word is selected.

#### Scenario: New word selected shows cached result or empty state
- **WHEN** the user selects a different word in the text viewer
- **THEN** the panel checks for a cached summary of the new word and displays it if found, or shows the empty state with the "解析開始" button

#### Scenario: Word deselected returns to initial state
- **WHEN** the selected text is cleared
- **THEN** the panel returns to the "単語を選択してください" state
