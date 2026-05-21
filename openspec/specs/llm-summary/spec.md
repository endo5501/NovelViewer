## Purpose

LLM-powered word/phrase summary panel in the right column with "no spoiler" / "spoiler" tabs. Triggers analysis on demand, runs the chunked extraction pipeline against context from the document folder (filtered by reading progress for the no-spoiler tab), parses the JSON response, and reacts to selection changes.

## Requirements

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
The "ネタバレあり" summary SHALL use search results from all text files in the document folder as context, passing them to the multi-stage pipeline.

#### Scenario: Generate spoiler summary from all files
- **WHEN** the user triggers analysis on the "ネタバレあり" tab for the word "アリス"
- **THEN** the system searches all text files in the current directory for "アリス", collects surrounding context from all matches, and passes them to the pipeline for chunked processing and summary generation

### Requirement: No-spoiler summary uses files up to current position
The "ネタバレなし" summary SHALL use search results only from text files up to and including the currently viewed file, based on numeric filename prefix ordering, passing them to the multi-stage pipeline.

#### Scenario: Generate no-spoiler summary limited to current file position
- **WHEN** the user is viewing file "040_chapter.txt" and triggers analysis on the "ネタバレなし" tab for the word "アリス"
- **THEN** the system searches only files with numeric prefix <= 40 and passes only those results to the pipeline for chunked processing and summary generation

#### Scenario: No-spoiler excludes later files
- **WHEN** the user is viewing file "040_chapter.txt" and files "050_chapter.txt" and "060_chapter.txt" also contain the search term
- **THEN** those later files are excluded from the contexts passed to the pipeline

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
The system SHALL construct LLM prompts using the multi-stage pipeline instead of a single prompt, removing the 10-entry context limit and processing all matched contexts through chunked fact extraction and aggregation.

#### Scenario: Build prompt via pipeline for many contexts
- **WHEN** the system builds a summary for the word "聖印" with 100 matching contexts found
- **THEN** the system passes all 100 contexts to the pipeline for chunked fact extraction and final summary generation, instead of limiting to 10 entries

#### Scenario: Build prompt via pipeline for few contexts
- **WHEN** the system builds a summary for the word "聖印" with 3 matching contexts found
- **THEN** the system passes all 3 contexts to the pipeline, which creates a single chunk and generates the summary in minimal stages

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

### Requirement: Research mark rendering in text viewer
The text viewer SHALL render visual marks on occurrences of words that have a cached summary in `word_summaries` for the currently displayed file's novel folder. The mark style SHALL be a dotted line for words that have only a no-spoiler cache, and a solid line for words that have a spoiler cache (with or without an additional no-spoiler cache). In horizontal display mode the mark SHALL be an underline below the base text; in vertical display mode the mark SHALL be a sidebar line placed alongside the base text. Marks SHALL be rendered as a line decoration only (no background color change), so that they coexist with the search highlight (yellow background) and the TTS highlight (green background) without overriding either.

#### Scenario: No-spoiler-only cache uses dotted underline in horizontal mode
- **WHEN** the word "ボブ" has a no-spoiler cache and no spoiler cache for the active folder, and the text viewer is in horizontal display mode
- **THEN** every occurrence of "ボブ" in the displayed file SHALL be rendered with a dotted underline beneath the base text

#### Scenario: Spoiler cache uses solid underline in horizontal mode
- **WHEN** the word "聖印" has a spoiler cache for the active folder (with or without a no-spoiler cache) and the text viewer is in horizontal display mode
- **THEN** every occurrence of "聖印" SHALL be rendered with a solid underline beneath the base text

#### Scenario: No-spoiler-only cache uses dotted sidebar line in vertical mode
- **WHEN** the word "ボブ" has a no-spoiler cache and no spoiler cache for the active folder, and the text viewer is in vertical display mode
- **THEN** every occurrence of "ボブ" SHALL be rendered with a dotted sidebar line alongside the base text

#### Scenario: Spoiler cache uses solid sidebar line in vertical mode
- **WHEN** the word "聖印" has a spoiler cache for the active folder and the text viewer is in vertical display mode
- **THEN** every occurrence of "聖印" SHALL be rendered with a solid sidebar line alongside the base text

#### Scenario: Mark coexists with search highlight
- **WHEN** the active search query is "アリス" and "アリス" also has a cached spoiler summary
- **THEN** the occurrences of "アリス" SHALL be rendered with the yellow search background AND the solid underline mark simultaneously

#### Scenario: Mark coexists with TTS highlight
- **WHEN** TTS is playing a sentence that contains a cached word
- **THEN** the cached word SHALL retain its mark (dotted or solid line) on top of the green TTS background

### Requirement: Mark matching uses longest-match with minimum length filter
The system SHALL determine which substrings of the displayed text are marked by performing a longest-match scan against the set of cached words for the active folder. Cached words shorter than 2 characters SHALL be excluded from the mark scan. When multiple cached words match overlapping ranges at the same starting position, the longest match SHALL be applied; non-overlapping matches SHALL all be applied independently.

#### Scenario: Minimum length filter excludes 1-character entries
- **WHEN** the cache contains a 1-character word "の"
- **THEN** no occurrences of "の" in the displayed text SHALL be marked

#### Scenario: Longest match wins for overlapping cached words
- **WHEN** the cache contains both "アリス" and "アリスの剣", and the text contains "アリスの剣を持って"
- **THEN** the range covering "アリスの剣" (5 characters) SHALL be marked, and a separate mark for "アリス" within that range SHALL NOT be applied

#### Scenario: Non-overlapping matches are independent
- **WHEN** the cache contains "アリス" and "聖印", and the text contains "アリスは聖印を持って"
- **THEN** "アリス" and "聖印" SHALL each be marked independently

#### Scenario: Substring match in unrelated word is still marked
- **WHEN** the cache contains "アリス" and the text contains "メアリス"
- **THEN** the "アリス" substring within "メアリス" SHALL be marked (this is an accepted false-positive limitation of the substring approach, mitigated by the 2-character minimum)

### Requirement: Marks apply to base text only, not ruby annotations
When the displayed text contains ruby annotations, the research mark SHALL be applied to the base text only. The ruby annotation text SHALL NOT receive a mark even if its content matches a cached word.

#### Scenario: Mark applied to ruby base text
- **WHEN** the text contains `<ruby>聖印<rt>せいいん</rt></ruby>` and "聖印" has a cached spoiler summary
- **THEN** the base text "聖印" SHALL be rendered with the solid underline (or sidebar line in vertical mode), while the ruby annotation "せいいん" SHALL remain unmarked

#### Scenario: Ruby annotation match does not trigger mark
- **WHEN** the text contains `<ruby>聖印<rt>せいいん</rt></ruby>` and "せいいん" has a cached summary but "聖印" does not
- **THEN** no mark SHALL be applied to either the base text "聖印" or the ruby annotation "せいいん"

### Requirement: Marks update when cache changes
The text viewer SHALL refresh the rendered marks when the underlying `word_summaries` rows for the active folder change. This includes new summary creation, re-analysis, and deletion via the history panel.

#### Scenario: New cache adds marks
- **WHEN** the user completes an analysis for a previously-uncached word
- **THEN** all occurrences of that word in the currently displayed file SHALL be marked on the next render

#### Scenario: Deletion removes marks
- **WHEN** the user deletes a history entry for a word that was being marked in the currently displayed file
- **THEN** the marks for that word SHALL be removed on the next render
