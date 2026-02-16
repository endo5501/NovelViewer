## ADDED Requirements

### Requirement: Right column visibility toggle button
The application SHALL display a toggle button in the AppBar that controls the visibility of the right column (SearchSummaryPanel).

#### Scenario: Toggle button is visible on launch
- **WHEN** the application launches
- **THEN** a toggle button for the right column visibility SHALL be displayed in the AppBar, before the download and settings buttons

#### Scenario: Toggle button shows panel-split icon when right column is visible
- **WHEN** the right column is visible
- **THEN** the toggle button SHALL display a panel-split icon (Icons.vertical_split)

#### Scenario: Toggle button shows sidebar icon when right column is hidden
- **WHEN** the right column is hidden
- **THEN** the toggle button SHALL display a sidebar icon (Icons.view_sidebar)

### Requirement: Right column visibility state management
The application SHALL manage the right column visibility state using a Riverpod StateProvider.

#### Scenario: Right column is visible by default
- **WHEN** the application launches
- **THEN** the right column SHALL be visible (default state is true)

#### Scenario: Clicking toggle hides the right column
- **WHEN** the right column is visible
- **AND** the user clicks the toggle button
- **THEN** the right column and its left-side VerticalDivider SHALL be hidden
- **AND** the center column SHALL expand to fill the freed space

#### Scenario: Clicking toggle shows the right column
- **WHEN** the right column is hidden
- **AND** the user clicks the toggle button
- **THEN** the right column (width 300px) and its left-side VerticalDivider SHALL be displayed
- **AND** the center column SHALL shrink to accommodate the right column
