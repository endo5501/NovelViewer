## ADDED Requirements

### Requirement: The narrow layout's drawers keep their contents clear of the system bars
A drawer is laid out at the origin of the display at the full height of the shell, so it reaches behind whatever the operating system draws over the top and bottom of the screen. In the narrow layout the application SHALL inset the contents of both the drawer and the end drawer by the display's own padding, so that the first interactive row of each panel — the left column's tab bar and the search panel's input field — and the last row of each panel's list are reachable rather than sitting under a status bar or a home indicator.

The inset SHALL be applied to the contents of the drawers only. The drawer's own surface SHALL continue to fill the height of the display, so the inset shows the drawer's own background rather than whatever lies beneath it.

The panels themselves SHALL NOT carry the inset, so the wide layout, where the same panels sit in the body below the app bar, is unchanged.

#### Scenario: The left drawer's tabs sit below the status bar
- **WHEN** the drawer is opened in the narrow layout on a display that reports a top padding
- **THEN** the top of the left column's tab bar is at or below that padding

#### Scenario: The left drawer's contents end above the home indicator
- **WHEN** the drawer is opened in the narrow layout on a display that reports a bottom padding
- **THEN** the bottom of the left column's contents is at or above the start of that padding

#### Scenario: The search drawer is inset the same way
- **WHEN** the end drawer is opened in the narrow layout on a display that reports top and bottom padding
- **THEN** the search panel's contents are inset by that padding exactly as the left drawer's are

#### Scenario: The drawer's surface still covers the inset area
- **WHEN** a drawer is opened on a display that reports a top padding
- **THEN** the drawer's own surface extends to the top of the display, so no part of the body shows through beside the status bar

#### Scenario: The wide layout carries no inset
- **WHEN** the home screen is rendered in the wide layout on a display that reports padding
- **THEN** the left column and the right column are laid out as before, with no inset of their own
