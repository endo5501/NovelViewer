## MODIFIED Requirements

### Requirement: Left column tab switching
The left column SHALL display a tab bar with three tabs: "ファイル" (file browser), "ブックマーク" (bookmark list), and "解析履歴" (LLM analysis history). The user SHALL be able to switch between tabs by tapping on them. Switching tabs SHALL preserve the state of the other tabs (current directory, bookmark list scroll position, history list scroll position).

#### Scenario: Application launches with file browser tab active
- **WHEN** the application launches
- **THEN** the left column SHALL display a tab bar at the top with "ファイル" tab selected by default
- **AND** the file browser panel SHALL be displayed below the tab bar

#### Scenario: User switches to bookmark tab
- **WHEN** the user taps the "ブックマーク" tab
- **THEN** the bookmark list panel SHALL be displayed below the tab bar
- **AND** the "ブックマーク" tab SHALL be visually indicated as active

#### Scenario: User switches to history tab
- **WHEN** the user taps the "解析履歴" tab
- **THEN** the LLM analysis history panel SHALL be displayed below the tab bar
- **AND** the "解析履歴" tab SHALL be visually indicated as active

#### Scenario: User switches back to file browser tab
- **WHEN** the user taps the "ファイル" tab while viewing the bookmark or history list
- **THEN** the file browser panel SHALL be displayed below the tab bar
- **AND** the file browser state (current directory, selected file) SHALL be preserved
