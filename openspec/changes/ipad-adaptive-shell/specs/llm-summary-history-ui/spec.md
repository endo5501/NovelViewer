## MODIFIED Requirements

### Requirement: Left column history tab
The left column SHALL include a third tab labeled "解析履歴" alongside "ファイル" and "ブックマーク" when the LLM summary feature is available on the running platform, and SHALL NOT include it otherwise — where summaries cannot be produced the tab lists nothing and can never be filled, so it is absent rather than empty. The user SHALL be able to switch to this tab by tapping on it. Tab switching SHALL preserve the state of the other tabs (current directory, bookmark list scroll position).

#### Scenario: User switches to history tab
- **WHEN** the user taps the "解析履歴" tab
- **THEN** the analysis history panel SHALL be displayed below the tab bar
- **AND** the "解析履歴" tab SHALL be visually indicated as active

#### Scenario: User switches back from history tab
- **WHEN** the user switches away from the "解析履歴" tab to another tab
- **THEN** the other tab's panel SHALL be displayed with its prior state preserved

#### Scenario: The history tab is absent where summaries are unavailable
- **WHEN** the left column is displayed on a platform where the LLM summary feature is unavailable
- **THEN** no "解析履歴" tab SHALL be present
- **AND** the "ファイル" and "ブックマーク" tabs SHALL remain and continue to switch as before
