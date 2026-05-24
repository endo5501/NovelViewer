## ADDED Requirements

### Requirement: Copy summary text from history entry context menu
The right-click context menu on a history entry SHALL include items that copy the cached summary text to the OS clipboard. For an entry whose underlying rows include only a no-spoiler cache, a single item "要約をコピー(ネタバレなし)" SHALL be displayed. For an entry whose underlying rows include only a spoiler cache, a single item "要約をコピー(ネタバレあり)" SHALL be displayed. For a "両" entry whose underlying rows include both types, both items SHALL be displayed. Selecting an item SHALL copy the corresponding summary text to the clipboard and display a brief feedback (e.g., a SnackBar with text such as "クリップボードにコピーしました").

#### Scenario: Copy no-spoiler summary from single-type entry
- **WHEN** the user right-clicks a history entry whose underlying rows include only a no-spoiler cache for the word "ボブ"
- **THEN** the context menu SHALL include the item "要約をコピー(ネタバレなし)" (in addition to the existing "削除" item)
- **AND** when the user selects that item, the no-spoiler summary text SHALL be written to the OS clipboard
- **AND** a brief feedback (e.g., SnackBar) SHALL confirm the copy

#### Scenario: Copy spoiler summary from single-type entry
- **WHEN** the user right-clicks a history entry whose underlying rows include only a spoiler cache for the word "聖印"
- **THEN** the context menu SHALL include the item "要約をコピー(ネタバレあり)" (in addition to the existing "削除" item)
- **AND** when the user selects that item, the spoiler summary text SHALL be written to the OS clipboard

#### Scenario: Copy either type from a 両 entry
- **WHEN** the user right-clicks a history entry whose underlying rows include both a no-spoiler and a spoiler cache for the word "アリス"
- **THEN** the context menu SHALL include both items "要約をコピー(ネタバレなし)" and "要約をコピー(ネタバレあり)" (in addition to the existing "削除" item)
- **AND** when the user selects "要約をコピー(ネタバレなし)", the no-spoiler summary text SHALL be written to the OS clipboard
- **AND** when the user selects "要約をコピー(ネタバレあり)", the spoiler summary text SHALL be written to the OS clipboard

#### Scenario: Copy operation does not modify history rows
- **WHEN** the user selects either copy item from the context menu
- **THEN** no `word_summaries` rows SHALL be modified, deleted, or re-ordered
- **AND** the history panel SHALL NOT refresh as a result of the copy
