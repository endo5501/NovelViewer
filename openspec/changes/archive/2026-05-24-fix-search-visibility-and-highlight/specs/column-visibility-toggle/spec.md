## MODIFIED Requirements

### Requirement: Right column visibility state management
The application SHALL manage the right column visibility state using a Riverpod NotifierProvider.

#### Scenario: Right column is hidden by default
- **WHEN** the application launches
- **THEN** the right column SHALL be hidden (default state is false)
- **AND** the center column SHALL fill the space that would otherwise be occupied by the right column

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
