## MODIFIED Requirements

### Requirement: Right column visibility toggle button
The application SHALL display a toggle button in the AppBar that controls the visibility of the right column (SearchSummaryPanel). That button SHALL be displayed only in the wide layout. In the narrow layout the right column exists solely as the search results drawer, which the AppBar's search button opens; a second button opening the same drawer, labelled as showing or hiding a column, would describe a layout that is not on screen.

#### Scenario: Toggle button is visible on launch
- **WHEN** the application launches in the wide layout
- **THEN** a toggle button for the right column visibility SHALL be displayed in the AppBar, before the download and settings buttons

#### Scenario: Toggle button shows panel-split icon when right column is visible
- **WHEN** the right column is visible
- **THEN** the toggle button SHALL display a panel-split icon (Icons.vertical_split)

#### Scenario: Toggle button shows sidebar icon when right column is hidden
- **WHEN** the right column is hidden
- **THEN** the toggle button SHALL display a sidebar icon (Icons.view_sidebar)

#### Scenario: Toggle button is absent in the narrow layout
- **WHEN** the application is displayed in the narrow layout
- **THEN** no right column visibility toggle button SHALL be present in the AppBar
- **AND** the search button SHALL remain the way to reach the search results

### Requirement: Right column visibility state management
The application SHALL manage the right column visibility state using a Riverpod NotifierProvider. That provider SHALL remain the single source of truth in both layouts: in the narrow layout the right column is an `endDrawer`, and the scaffold's drawer state SHALL follow the provider rather than compete with it. Setting the provider to true SHALL open the drawer, and dismissing the drawer by any means SHALL set the provider back to false, so that the keyboard shortcut, the selection search and the escape key keep working through the provider alone.

#### Scenario: Right column is hidden by default
- **WHEN** the application launches
- **THEN** the right column SHALL be hidden (default state is false)
- **AND** the center column SHALL fill the space that would otherwise be occupied by the right column

#### Scenario: Clicking toggle hides the right column
- **WHEN** the right column is visible in the wide layout
- **AND** the user clicks the toggle button
- **THEN** the right column and its left-side VerticalDivider SHALL be hidden
- **AND** the center column SHALL expand to fill the freed space

#### Scenario: Clicking toggle shows the right column
- **WHEN** the right column is hidden in the wide layout
- **AND** the user clicks the toggle button
- **THEN** the right column (width 300px) and its left-side VerticalDivider SHALL be displayed
- **AND** the center column SHALL shrink to accommodate the right column

#### Scenario: The drawer opens when the provider becomes visible
- **WHEN** the right column visibility state becomes true in the narrow layout, from any source
- **THEN** the end drawer SHALL open showing the search results panel
- **AND** the text viewer SHALL keep the full body width beneath it

#### Scenario: Changing to the wide layout keeps the search session
- **WHEN** the display grows past the breakpoint while the end drawer is open
- **THEN** the right column visibility state SHALL remain true
- **AND** the search results SHALL be shown as the wide layout's right column
- **AND** the disappearance of the drawer SHALL NOT be treated as the reader dismissing it

#### Scenario: Dismissing the drawer clears the visibility state
- **WHEN** the reader dismisses the end drawer in the narrow layout by tapping the scrim or by a system back gesture
- **THEN** the right column visibility state SHALL become false
- **AND** a subsequent search shortcut SHALL open the drawer again
