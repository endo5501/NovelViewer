## Purpose

LLM-powered word/phrase summary panel in the right column with snapshot-based analysis. Triggers analysis on demand, runs the chunked extraction pipeline against context from the document folder (filtered by the chosen `covered_up_to_episode` upper bound), parses the JSON response, and reacts to selection changes.
## Requirements
### Requirement: Snapshot-based analysis scope
Each LLM analysis run SHALL produce a single snapshot row whose `covered_up_to_episode` is determined by the analysis trigger. The "解析開始(ネタバレなし)" trigger SHALL use the numeric prefix of the currently viewed file as the upper bound; the "解析開始(ネタバレあり)" trigger SHALL use the numeric prefix of the highest-prefix text file in the folder at the moment of analysis. When the current file (no-spoiler) has no numeric prefix, the 1-origin lexical sort position of the file within the folder SHALL be used. The collected context passed to the pipeline SHALL include search results from files whose numeric prefix (or lexical rank, for prefix-less files) is less than or equal to the chosen upper bound.

#### Scenario: ネタバレなし trigger uses current file's prefix
- **WHEN** the user is viewing "040_chapter.txt" and triggers no-spoiler analysis for the word "アリス"
- **THEN** the pipeline SHALL receive context from files whose numeric prefix is `<= 40`
- **AND** the saved snapshot SHALL have `covered_up_to_episode=40`

#### Scenario: ネタバレあり trigger uses the folder's highest prefix
- **WHEN** the user triggers spoiler analysis for the word "アリス" while the folder contains files with prefixes `[10, 20, 30, 40]`
- **THEN** the pipeline SHALL receive context from files with prefix `<= 40` (i.e., all files)
- **AND** the saved snapshot SHALL have `covered_up_to_episode=40`

#### Scenario: ネタバレあり after content is added produces a new snapshot
- **WHEN** the user previously ran spoiler analysis when the folder had `covered_up_to_episode=10`, the folder later grows to highest-prefix 20, and the user runs spoiler analysis again
- **THEN** a new row SHALL be saved with `covered_up_to_episode=20`, leaving the prior `covered_up_to_episode=10` row intact

#### Scenario: ネタバレなし trigger on a prefix-less file uses lexical rank
- **WHEN** the user is viewing "intro.txt" whose folder's text files sorted lexically are `[intro.txt, part1.txt, part2.txt]` and triggers no-spoiler analysis
- **THEN** the saved snapshot SHALL have `covered_up_to_episode=1`

### Requirement: Prompt construction for word summary
The system SHALL construct LLM prompts using the multi-stage pipeline instead of a single prompt, removing the 10-entry context limit and processing all matched contexts through chunked fact extraction and aggregation. The contexts passed to the pipeline SHALL be pre-filtered by the analysis trigger's snapshot upper bound (see "Snapshot-based analysis scope").

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

### Requirement: Research mark rendering uses a uniform style
The text viewer SHALL render visual marks on occurrences of words that have **any** cached snapshot in `word_summaries` for the currently displayed file's novel folder. A single, uniform mark style SHALL be used regardless of the `covered_up_to_episode` values of the existing snapshots. In horizontal display mode the mark SHALL be a solid underline below the base text; in vertical display mode the mark SHALL be a solid sidebar line placed alongside the base text. Marks SHALL be rendered as a line decoration only (no background color change), so that they coexist with the search highlight (yellow background) and the TTS highlight (green background) without overriding either.

#### Scenario: Any snapshot triggers a solid underline in horizontal mode
- **WHEN** the word "ボブ" has at least one cached snapshot for the active folder and the text viewer is in horizontal display mode
- **THEN** every occurrence of "ボブ" in the displayed file SHALL be rendered with a solid underline beneath the base text

#### Scenario: Any snapshot triggers a solid sidebar line in vertical mode
- **WHEN** the word "ボブ" has at least one cached snapshot for the active folder and the text viewer is in vertical display mode
- **THEN** every occurrence of "ボブ" SHALL be rendered with a solid sidebar line alongside the base text

#### Scenario: Mark coexists with search highlight
- **WHEN** the active search query is "アリス" and "アリス" has at least one cached snapshot
- **THEN** the occurrences of "アリス" SHALL be rendered with the yellow search background AND the solid underline mark simultaneously

#### Scenario: Mark coexists with TTS highlight
- **WHEN** TTS is playing a sentence that contains a cached word
- **THEN** the cached word SHALL retain its solid mark on top of the green TTS background

### Requirement: Mark matching uses longest-match with minimum length filter
The system SHALL determine which substrings of the displayed text are marked by performing a longest-match scan against the set of cached words for the active folder. A word is "cached" when at least one snapshot row exists for `(folder_name, word)` regardless of `covered_up_to_episode`. Cached words shorter than 2 characters SHALL be excluded from the mark scan. When multiple cached words match overlapping ranges at the same starting position, the longest match SHALL be applied; non-overlapping matches SHALL all be applied independently.

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
The text viewer SHALL refresh the rendered marks when the underlying `word_summaries` rows for the active folder change. This includes new snapshot creation, re-analysis (overwrite of a matching `covered_up_to_episode`), and deletion via the history panel.

#### Scenario: New snapshot adds marks
- **WHEN** the user completes an analysis for a previously-uncached word
- **THEN** all occurrences of that word in the currently displayed file SHALL be marked on the next render

#### Scenario: Deletion removes marks
- **WHEN** the user deletes a history entry for a word that was being marked in the currently displayed file
- **THEN** the marks for that word SHALL be removed on the next render (assuming no other snapshots exist for the word)

### Requirement: Analysis modal displays pipeline progress

The analysis modal shown during LLM word/phrase analysis SHALL subscribe to the pipeline's progress notifications and display a phase-appropriate label with current/total counters. The modal SHALL continue to show a spinner alongside the label so the user has both a visual cue that work is ongoing and a textual cue of what is happening.

The label content SHALL be:

- Before any progress event arrives (e.g., during the initial context search), the existing "LLM 解析中…" / locale-equivalent label.
- During the initial fact-extraction round (`round = 1`), a localized "情報を抽出中" label with `current / total` counters.
- During subsequent refinement rounds (`round >= 2`), a localized "絞り込み N 周目" label (where N is the `round` value) with `current / total` counters.
- During the final summary phase, a localized "最終要約を生成中…" label without counters.

The modal SHALL update reactively each time a new progress event arrives, without dismissing and re-opening the dialog. Modal dismissal SHALL continue to be driven by completion or error of the analysis, not by progress events.

#### Scenario: Initial label before any progress event

- **WHEN** the user triggers an analysis and the modal opens, but no progress event has been emitted yet (still in context search)
- **THEN** the modal displays the localized "LLM 解析中…" label

#### Scenario: Fact extraction shows current/total

- **WHEN** the pipeline emits a fact-extraction event with `round = 1`, `current = 2`, `total = 5`
- **THEN** the modal displays a label matching "情報を抽出中 (2 / 5)" in the active locale

#### Scenario: Refinement shows round number

- **WHEN** the pipeline emits a fact-extraction event with `round = 3`, `current = 1`, `total = 2`
- **THEN** the modal displays a label matching "絞り込み 3 周目 (1 / 2)" in the active locale

#### Scenario: Final summary shows summary label

- **WHEN** the pipeline emits the `AnalysisGeneratingFinalSummary` event
- **THEN** the modal displays the localized "最終要約を生成中…" label and stops showing the chunk counters

#### Scenario: Modal stays open across progress events

- **WHEN** multiple progress events are emitted in succession during a single analysis
- **THEN** the same modal route remains active, only its inner content changes; the dialog is not re-pushed onto the navigator

#### Scenario: Modal closes only on completion or error

- **WHEN** the pipeline finishes successfully or throws an exception
- **THEN** the modal route is removed from the navigator exactly as it is in the prior behavior, regardless of which progress event was last seen
