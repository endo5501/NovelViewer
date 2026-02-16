## MODIFIED Requirements

### Requirement: Left column displays file browser
The left column SHALL contain a tabbed interface with two tabs: a file browser tab and a bookmark list tab. The file browser tab SHALL be selected by default on application launch. The left column SHALL use a `TabBar` + `TabBarView` for switching between the file browser component and the bookmark list component.

#### Scenario: Left column shows tabbed interface on launch
- **WHEN** the application launches
- **THEN** the left column SHALL display a tab bar at the top with "ファイル" and "ブックマーク" tabs
- **AND** the "ファイル" tab SHALL be selected by default showing the file browser widget

#### Scenario: Left column maintains fixed width with tabs
- **WHEN** the left column displays the tabbed interface
- **THEN** the left column width SHALL remain at 250px including the tab bar
