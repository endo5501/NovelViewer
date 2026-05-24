## MODIFIED Requirements

### Requirement: Spoiler summary uses all files
The "spoiler" (`SummaryType.spoiler`) summary SHALL use search results from all text files in the document folder as context, passing them to the multi-stage pipeline.

#### Scenario: Generate spoiler summary from all files
- **WHEN** the user triggers spoiler analysis for the word "アリス" (via the right-click context menu's "解析開始(ネタバレあり)" item)
- **THEN** the system searches all text files in the current directory for "アリス", collects surrounding context from all matches, and passes them to the pipeline for chunked processing and summary generation

### Requirement: No-spoiler summary uses files up to current position
The "no-spoiler" (`SummaryType.noSpoiler`) summary SHALL use search results only from text files up to and including the currently viewed file, based on numeric filename prefix ordering, passing them to the multi-stage pipeline.

#### Scenario: Generate no-spoiler summary limited to current file position
- **WHEN** the user is viewing file "040_chapter.txt" and triggers no-spoiler analysis for the word "アリス" (via the right-click context menu's "解析開始(ネタバレなし)" item)
- **THEN** the system searches only files with numeric prefix <= 40 and passes only those results to the pipeline for chunked processing and summary generation

#### Scenario: No-spoiler excludes later files
- **WHEN** the user is viewing file "040_chapter.txt" and files "050_chapter.txt" and "060_chapter.txt" also contain the search term
- **THEN** those later files are excluded from the contexts passed to the pipeline

## REMOVED Requirements

### Requirement: LLM summary panel with spoiler tabs
**Reason**: The right-column LLM summary panel is replaced by the inline hover popup (`llm-summary-hover-popup`) and the right-click context menu trigger (`llm-summary-context-menu-trigger`). The two-tab layout is no longer applicable; the equivalent split between "no spoiler" and "spoiler" is now represented as separate menu items at trigger time and a [なし|あり] switching pill inside the hover popup when both types are cached.
**Migration**: Users access cached summaries by hovering over marked words in the text viewer. To trigger a new analysis, users select text and choose "解析開始(ネタバレなし)" or "解析開始(ネタバレあり)" from the right-click context menu. To browse all cached summaries, users use the "解析履歴" tab in the left column.

### Requirement: Analysis start button
**Reason**: The "解析開始" button living inside the right-column panel is removed. Analysis is now triggered exclusively from the right-click context menu items defined by `llm-summary-context-menu-trigger`.
**Migration**: Replaced by `llm-summary-context-menu-trigger`'s "Trigger analysis from context menu items" requirement.

### Requirement: LLM summary display states
**Reason**: The right-column panel and its state-based content (selection prompt, configuration prompt, loading indicator, error message, success display) are removed. Equivalent affordances are distributed across the hover popup (display only when cache exists), the analysis modal (loading), and SnackBar feedback (success/failure).
**Migration**:
- "No word selected" state: no longer applicable (no permanent panel exists).
- "LLM not configured" state: the right-click menu items will still appear, but the analysis call SHALL surface a clear error via SnackBar (handled by `llm-summary-context-menu-trigger`'s "Modal closes when analysis fails" scenario).
- "Analysis in progress" state: replaced by the analysis-in-progress modal dialog in `llm-summary-context-menu-trigger`.
- "Analysis completed successfully": replaced by SnackBar feedback in `llm-summary-context-menu-trigger`, with the resulting cached summary being immediately viewable via hover popup.
- "Analysis failed with error": replaced by SnackBar feedback in `llm-summary-context-menu-trigger`.

### Requirement: Summary reacts to selected text changes
**Reason**: The right-column panel that watched `selectedTextProvider` and auto-loaded cached summaries is removed. Cache lookup now happens on-demand when the user hovers over a marked word, not on selection. The `selectedTextProvider` itself remains in the codebase for other features (e.g., dictionary add).
**Migration**: Selecting text in the viewer no longer triggers any LLM-summary-related UI change. To view a cached summary, hover over the marked word. To trigger a new analysis, use the right-click context menu.
