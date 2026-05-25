## MODIFIED Requirements

### Requirement: Trigger analysis from context menu items
When the user selects "解析開始(ネタバレなし)" or "解析開始(ネタバレあり)" from the context menu, the system SHALL invoke the LLM summary pipeline for the selected text with a `coveredUpToEpisode` argument derived from the menu choice:

- "解析開始(ネタバレなし)" → `coveredUpToEpisode` equals the numeric prefix of the currently viewed file (or its 1-origin lexical rank within the folder when no numeric prefix exists).
- "解析開始(ネタバレあり)" → `coveredUpToEpisode` equals the numeric prefix of the highest-prefix text file in the folder (or the lexical rank of the last file when no numeric prefix exists).

The trigger SHALL NOT depend on the existence of prior cached entries — if a `word_summaries` row already exists for `(folder_name, word, coveredUpToEpisode)`, the new analysis result SHALL silently overwrite it without showing any confirmation dialog. The context menu item labels SHALL always read "解析開始(…)" regardless of whether a snapshot exists at the resulting episode.

#### Scenario: ネタバレなし trigger writes a snapshot for current file's episode
- **WHEN** the user selects "アリス" while viewing "040_chapter.txt" and chooses "解析開始(ネタバレなし)", and no snapshot exists at `covered_up_to_episode=40`
- **THEN** the system SHALL invoke the LLM summary pipeline with `word="アリス"`, `coveredUpToEpisode=40`, and the active folder context, storing the result in `word_summaries`

#### Scenario: ネタバレあり trigger writes a snapshot for highest-prefix file
- **WHEN** the user selects "アリス" and chooses "解析開始(ネタバレあり)" while the folder's highest-prefix file is "120_chapter.txt", and no snapshot exists at `covered_up_to_episode=120`
- **THEN** the system SHALL invoke the LLM summary pipeline with `word="アリス"`, `coveredUpToEpisode=120`, and the active folder context, storing the result in `word_summaries`

#### Scenario: Re-analysis silently overwrites matching snapshot
- **WHEN** the user selects a word while viewing "040_chapter.txt", a snapshot at `covered_up_to_episode=40` already exists, and the user chooses "解析開始(ネタバレなし)"
- **THEN** no confirmation dialog SHALL be shown
- **AND** the existing `(folder_name, word, covered_up_to_episode=40)` row SHALL be overwritten with the new summary text and updated timestamps

#### Scenario: Menu labels do not change when snapshots exist
- **WHEN** the user selects a word that already has multiple snapshots and opens the context menu
- **THEN** the items SHALL read "解析開始(ネタバレなし)" and "解析開始(ネタバレあり)" (NOT "再解析" or any variant)

#### Scenario: ネタバレなし on a prefix-less current file uses lexical rank
- **WHEN** the user selects "アリス" while viewing "intro.txt" whose folder's text files sorted lexically are `[intro.txt, part1.txt, part2.txt]`, and chooses "解析開始(ネタバレなし)"
- **THEN** the system SHALL invoke the pipeline with `coveredUpToEpisode=1`

#### Scenario: ネタバレあり captures the current "全話" boundary
- **WHEN** the folder originally contained files with prefixes `[10, 20]` and the user ran "解析開始(ネタバレあり)" producing a snapshot at `covered_up_to_episode=20`; later the folder grows to `[10, 20, 30, 40]` and the user runs "解析開始(ネタバレあり)" again
- **THEN** a new snapshot SHALL be written at `covered_up_to_episode=40`, leaving the existing `covered_up_to_episode=20` snapshot intact
