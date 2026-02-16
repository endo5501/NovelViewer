## MODIFIED Requirements

### Requirement: Three-column layout structure
The application SHALL display a three-column layout as its main screen, consisting of a left column (file browser), a center column (text viewer), and a right column (search/summary area). The right column SHALL support toggling its visibility.

#### Scenario: All three columns are visible
- **WHEN** the application launches
- **THEN** three columns are displayed side by side separated by vertical dividers

#### Scenario: Center column expands to fill available space
- **WHEN** the window is resized
- **THEN** the center column expands or contracts to fill the remaining space while left and right columns maintain their fixed width

#### Scenario: Center column fills remaining space when right column is hidden
- **WHEN** the right column visibility is toggled off
- **THEN** the center column expands to fill the space previously occupied by the right column and its divider
