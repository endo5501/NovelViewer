## MODIFIED Requirements

### Requirement: Left column displays file browser
The left column SHALL contain a tabbed interface whose first two tabs are a file browser tab and a bookmark list tab, followed by any further tabs contributed by capabilities that are available on the running platform. The file browser tab SHALL be selected by default on application launch. The left column SHALL use a `TabBar` + `TabBarView` for switching between the panels.

The left column SHALL be presented in a `Drawer` at every display width, in the wide layout and in the narrow layout alike, and SHALL NOT occupy a share of the main row in either. The main row is therefore the text viewer, beside the search panel when that one is visible.

The drawer SHALL be as wide as the display less 64 logical pixels, capped at 560 logical pixels. It is no longer a fixed 250px pane: long novel titles and episode names were truncated at that width, and on a touch display the tooltip that would have revealed them does not appear.

#### Scenario: Left column shows tabbed interface on launch
- **WHEN** the application launches and the drawer holding the left column is opened
- **THEN** the left column SHALL display a tab bar at the top whose first two tabs are "ファイル" and "ブックマーク"
- **AND** the "ファイル" tab SHALL be selected by default showing the file browser widget

#### Scenario: Left column maintains fixed width with tabs
- **WHEN** the left column displays the tabbed interface inside the drawer
- **THEN** the left column width SHALL be the width of the drawer, including the tab bar — the display width less 64 logical pixels, capped at 560
- **AND** on a display 1440 logical pixels wide that is 560 logical pixels, and on a display 390 logical pixels wide it is 326

#### Scenario: Left column moves into a drawer in the narrow layout
- **WHEN** the application is displayed in the narrow layout
- **THEN** the left column SHALL NOT occupy space in the main row
- **AND** it SHALL be displayed inside the drawer opened from the app bar

#### Scenario: Left column is not part of the main row in the wide layout
- **WHEN** the application is displayed in the wide layout
- **THEN** the left column SHALL NOT occupy space in the main row
- **AND** it SHALL be displayed inside the drawer opened from the app bar, at the same width it has in the narrow layout for the same display width
