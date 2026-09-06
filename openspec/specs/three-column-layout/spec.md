## Purpose

Three-column main layout (left: file browser + bookmark tabs / center: text viewer / right: search & summary panel) as the wide layout. The left column is a 250px tabbed pane (`TabBar` + `TabBarView`) whose first two tabs are the file browser and the bookmark list, followed by any further tabs contributed by capabilities available on the running platform, defaulting to the file browser tab on launch. Below the shell breakpoint the three columns are not presented side by side: the left column moves into a `Drawer` of the same 250px width, so the panel is laid out identically in both layouts, and the text viewer takes the full width of the body.

## Requirements

### Requirement: Left column displays file browser
The left column SHALL contain a tabbed interface whose first two tabs are a file browser tab and a bookmark list tab, followed by any further tabs contributed by capabilities that are available on the running platform. The file browser tab SHALL be selected by default on application launch. The left column SHALL use a `TabBar` + `TabBarView` for switching between the panels.

In the wide layout the left column SHALL be a fixed 250px pane in the main row. In the narrow layout it SHALL be presented in a `Drawer` of the same width instead, so the panel is laid out identically in both layouts and the text viewer receives the full body width.

#### Scenario: Left column shows tabbed interface on launch
- **WHEN** the application launches
- **THEN** the left column SHALL display a tab bar at the top whose first two tabs are "ファイル" and "ブックマーク"
- **AND** the "ファイル" tab SHALL be selected by default showing the file browser widget

#### Scenario: Left column maintains fixed width with tabs
- **WHEN** the left column displays the tabbed interface in the wide layout
- **THEN** the left column width SHALL remain at 250px including the tab bar

#### Scenario: Left column moves into a drawer in the narrow layout
- **WHEN** the application is displayed in the narrow layout
- **THEN** the left column SHALL NOT occupy space in the main row
- **AND** it SHALL be displayed, at the same 250px width, inside the drawer opened from the app bar
