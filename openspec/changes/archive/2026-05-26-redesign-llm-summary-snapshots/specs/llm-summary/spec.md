## ADDED Requirements

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

## MODIFIED Requirements

### Requirement: Prompt construction for word summary
The system SHALL construct LLM prompts using the multi-stage pipeline instead of a single prompt, removing the 10-entry context limit and processing all matched contexts through chunked fact extraction and aggregation. The contexts passed to the pipeline SHALL be pre-filtered by the analysis trigger's snapshot upper bound (see "Snapshot-based analysis scope").

#### Scenario: Build prompt via pipeline for many contexts
- **WHEN** the system builds a summary for the word "聖印" with 100 matching contexts found
- **THEN** the system passes all 100 contexts to the pipeline for chunked fact extraction and final summary generation, instead of limiting to 10 entries

#### Scenario: Build prompt via pipeline for few contexts
- **WHEN** the system builds a summary for the word "聖印" with 3 matching contexts found
- **THEN** the system passes all 3 contexts to the pipeline, which creates a single chunk and generates the summary in minimal stages

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

### Requirement: Marks update when cache changes
The text viewer SHALL refresh the rendered marks when the underlying `word_summaries` rows for the active folder change. This includes new snapshot creation, re-analysis (overwrite of a matching `covered_up_to_episode`), and deletion via the history panel.

#### Scenario: New snapshot adds marks
- **WHEN** the user completes an analysis for a previously-uncached word
- **THEN** all occurrences of that word in the currently displayed file SHALL be marked on the next render

#### Scenario: Deletion removes marks
- **WHEN** the user deletes a history entry for a word that was being marked in the currently displayed file
- **THEN** the marks for that word SHALL be removed on the next render (assuming no other snapshots exist for the word)

## REMOVED Requirements

### Requirement: Spoiler summary uses all files
**Reason**: Replaced by the more general "Snapshot-based analysis scope" requirement, which covers spoiler-mode behavior as one case (upper bound = highest-prefix file).
**Migration**: Existing trigger code SHALL pass the highest-prefix file's number as the snapshot upper bound when the "解析開始(ネタバレあり)" menu item is selected.

### Requirement: No-spoiler summary uses files up to current position
**Reason**: Replaced by the more general "Snapshot-based analysis scope" requirement, which covers no-spoiler-mode behavior as one case (upper bound = current file's prefix).
**Migration**: Existing trigger code SHALL pass the current file's numeric prefix (or 1-origin lexical rank when no prefix exists) as the snapshot upper bound when the "解析開始(ネタバレなし)" menu item is selected.

### Requirement: Research mark rendering in text viewer
**Reason**: Replaced by "Research mark rendering uses a uniform style". The dotted vs. solid distinction relied on `summary_type`, which is being removed.
**Migration**: All occurrences of cached words SHALL be rendered with the solid mark style. Visual differentiation between "only-future snapshots exist" and "past snapshots exist" SHALL be conveyed through the hover popup (warning icon), not through the mark style on the text itself. The "Marks apply to base text only, not ruby annotations" requirement is unchanged and remains in effect under the same wording in the active spec.
