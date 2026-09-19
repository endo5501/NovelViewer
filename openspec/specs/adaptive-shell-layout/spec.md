## Purpose

Shapes the main screen around one question: how much room is left for the body text. The file browser is not part of that question — it lives in a `Drawer` at every display width, as wide as the display allows up to a cap, because a reader goes there to choose what to read next and comes back to the text. What the display width decides is where the search results go: beside the text as a column in the wide layout, over it as an `endDrawer` in the narrow one. That decision is made by a single pure function that never reads `dart:io`'s `Platform`; the width is read in exactly one place, the home screen, and the resolved layout is handed down to the surfaces that change with it. The breakpoint is a Riverpod provider, so a widget test selects either layout by overriding it instead of resizing the viewport.

The file browser drawer opens on launch, once the restoration of the last reading session has settled, so the app begins by asking what to read with the last-read episode already selected. Both drawers open only from the app bar or a shortcut — edge drags stay with the vertical viewer's page turning. The file browser drawer closes on a file selection and stays put across the breakpoint; the end drawer closes when the layout that shows the same panel as a column takes over. Escape dismisses one layer at a time, taking the file browser drawer before the search beneath it and standing aside for a dialog above it. Because a drawer is laid out at the origin at the full height of the shell, where the app bar's own inset handling does not reach, the contents of both drawers are inset by the display's padding so they stay clear of a status bar above and a home indicator below; the inset sits in the drawers rather than in the panels, which are shared with the body.

## Requirements

### Requirement: The shell's shape is decided by display width through a pure function
The system SHALL decide which of two shell layouts to present — narrow or wide — from the display width and a breakpoint, using a single pure function. That function SHALL NOT read `dart:io`'s `Platform`, so the decision is about how much room the body text has rather than about which device is running the application, and so it can be evaluated directly in a unit test for any width.

#### Scenario: A width below the breakpoint selects the narrow layout
- **WHEN** the layout is resolved for a width smaller than the breakpoint
- **THEN** the narrow layout is selected

#### Scenario: A width at or above the breakpoint selects the wide layout
- **WHEN** the layout is resolved for a width equal to or greater than the breakpoint
- **THEN** the wide layout is selected

#### Scenario: The decision is made without touching the platform
- **WHEN** the resolution function is called from a unit test with an explicit width and breakpoint
- **THEN** it returns the corresponding layout regardless of the platform the test itself runs on

### Requirement: The width is read in one place and the breakpoint is injectable
The application SHALL read the display width for the purpose of choosing a shell layout in exactly one place — the home screen — and SHALL distribute the resolved layout to the surfaces that need it rather than letting each of them consult `MediaQuery`. The breakpoint SHALL be exposed as a Riverpod provider so a widget test can select either layout by overriding it, without resizing the test viewport.

The default breakpoint SHALL be 800 logical pixels, the width the desktop build already restores no window smaller than. It is kept at that value now that the left column has moved into a drawer: it remains the narrowest width at which the text viewer and the search results column can share the body without crowding the text. No minimum size is imposed on the native window, so a reader may make one narrower and receive the narrow layout there too.

#### Scenario: Only the home screen resolves the layout
- **WHEN** the widgets that change with the shell layout are inspected
- **THEN** none of them reads `MediaQuery` to decide the layout; each receives the resolved layout from the home screen

#### Scenario: The layout can be selected in tests without resizing the viewport
- **WHEN** a widget test overrides the breakpoint provider with a value greater than the test viewport width
- **THEN** the narrow layout is rendered, and overriding it with a smaller value renders the wide layout

#### Scenario: The default breakpoint matches the desktop's own minimum
- **WHEN** the default breakpoint is compared with the minimum size the desktop build restores a window to
- **THEN** they are the same width, so the fold continues a judgement the desktop build already makes rather than introducing a new one

#### Scenario: A desktop window narrowed past the breakpoint gets the narrow layout
- **WHEN** a desktop window is resized below the breakpoint
- **THEN** the narrow layout is presented there as well, because the search results column would crowd the body text at that width whatever the platform

### Requirement: Drawers open only from the app bar
The application SHALL disable the scaffold's edge-drag gestures for both drawers, in both layouts. The vertical text viewer already interprets a horizontal drag as a page turn, so an edge drag that opened a drawer would take page turning away at exactly the edges of the screen. The app bar's buttons SHALL be the only pointer-driven way to open either drawer.

Because the file browser drawer now exists at every display width, the app bar SHALL offer its button at every display width.

#### Scenario: An edge drag does not open a drawer
- **WHEN** the reader drags horizontally from the left or right edge of the screen, in either layout
- **THEN** no drawer opens, and the gesture is left to the viewer beneath

#### Scenario: The app bar opens the drawer
- **WHEN** the reader taps the app bar's drawer button, in either layout
- **THEN** the drawer opens

### Requirement: A drawer closes when it stops being useful
The file browser drawer SHALL be closed when the reader selects a file, so that the newly opened text is visible without a further dismissal. It SHALL NOT be closed when the display width crosses the breakpoint, because it is present in both layouts and a reader part-way through choosing would lose their place for no reason.

The end drawer holding the search results SHALL be closed when the layout changes from narrow to wide, so that no drawer is left open over a layout that shows the same panel as a column.

#### Scenario: Selecting a file closes the drawer
- **WHEN** the reader opens the drawer and selects a file from any of its tabs, in either layout
- **THEN** the drawer closes and the selected file is shown in the text viewer

#### Scenario: Widening the window leaves the file browser drawer open
- **WHEN** the file browser drawer is open and the display width grows past the breakpoint
- **THEN** the drawer stays open over the wide layout

#### Scenario: Widening the window closes the drawer
- **WHEN** the end drawer holding the search results is open and the display width grows past the breakpoint
- **THEN** the end drawer is closed and the search results are presented as the right column instead

### Requirement: The left column always lives in a drawer
The application SHALL present the left column — the tabbed file browser — inside a `Drawer` at every display width, in the narrow layout and in the wide layout alike. The left column SHALL NOT occupy a share of the body in either layout; the body is the text viewer, beside the right column when that one is shown.

The drawer SHALL be as wide as the display less 64 logical pixels, capped at 560 logical pixels, so that a long novel title or episode name is readable rather than truncated. The cap keeps the drawer from swallowing a desktop window whole, and subtracting 64 keeps a strip of the body visible on a phone so it stays clear that the drawer is an overlay.

This replaces the earlier rule that the drawer matched the width of a left column in the wide layout: there is no such column any more, and matching it was what kept the panel too narrow to read.

#### Scenario: The wide layout has no left column in its body
- **WHEN** the home screen is rendered in the wide layout
- **THEN** the body contains the text viewer, and the right column when it is visible, and the left column is in neither

#### Scenario: The drawer is reachable in the wide layout
- **WHEN** the drawer is opened in the wide layout
- **THEN** the left column panel is displayed inside it

#### Scenario: The drawer is reachable in the narrow layout
- **WHEN** the drawer is opened in the narrow layout
- **THEN** the left column panel is displayed inside it, at the same width it has in the wide layout for the same display width

#### Scenario: The drawer follows the display width up to the cap
- **WHEN** the drawer is laid out on a display 1440 logical pixels wide
- **THEN** its width is 560 logical pixels

#### Scenario: The drawer leaves a strip of the body visible on a narrow display
- **WHEN** the drawer is laid out on a display 390 logical pixels wide
- **THEN** its width is 326 logical pixels, so the body remains visible beside it

### Requirement: The narrow layout moves the search results into an end drawer
In the narrow layout the application SHALL present the right column — the search results — as an `endDrawer`, and the text viewer SHALL occupy the full width of the body with no column divider. In the wide layout the right column SHALL be laid out beside the text viewer exactly as before, shown or hidden by its own visibility state.

The narrow/wide decision therefore governs the placement of the right column alone. The left column is a drawer either way.

#### Scenario: The narrow layout gives the whole body to the text viewer
- **WHEN** the home screen is rendered in the narrow layout
- **THEN** the body contains the text viewer and no column dividers, and the right column is not inside the body

#### Scenario: The wide layout keeps the right column beside the viewer
- **WHEN** the home screen is rendered in the wide layout with the right column visible
- **THEN** the text viewer and the right column are laid out in a row, separated by a divider, and the scaffold presents no end drawer

### Requirement: The drawers keep their contents clear of the system bars
A drawer is laid out at the origin of the display at the full height of the shell, so it reaches behind whatever the operating system draws over the top and bottom of the screen. The application SHALL inset the contents of both the drawer and the end drawer by the display's own padding, so that the first interactive row of each panel — the left column's tab bar and the search panel's input field — and the last row of each panel's list are reachable rather than sitting under a status bar or a home indicator.

The inset SHALL apply at every display width, because the file browser drawer exists at every display width. On a display that reports no padding it has no visible effect.

The inset SHALL be applied to the contents of the drawers only. The drawer's own surface SHALL continue to fill the height of the display, so the inset shows the drawer's own background rather than whatever lies beneath it.

The panels themselves SHALL NOT carry the inset, so the search panel is unchanged where it sits in the body of the wide layout.

#### Scenario: The left drawer's tabs sit below the status bar
- **WHEN** the drawer is opened on a display that reports a top padding, in either layout
- **THEN** the top of the left column's tab bar is at or below that padding

#### Scenario: The left drawer's contents end above the home indicator
- **WHEN** the drawer is opened on a display that reports a bottom padding, in either layout
- **THEN** the bottom of the left column's contents is at or above the start of that padding

#### Scenario: The search drawer is inset the same way
- **WHEN** the end drawer is opened in the narrow layout on a display that reports top and bottom padding
- **THEN** the search panel's contents are inset by that padding exactly as the left drawer's are

#### Scenario: The drawer's surface still covers the inset area
- **WHEN** a drawer is opened on a display that reports a top padding
- **THEN** the drawer's own surface extends to the top of the display, so no part of the body shows through beside the status bar

#### Scenario: The right column in the body carries no inset
- **WHEN** the home screen is rendered in the wide layout on a display that reports padding
- **THEN** the right column is laid out below the app bar with no inset of its own

### Requirement: The file browser drawer opens once the reading session has been restored
The application SHALL open the file browser drawer on launch, so that the reader begins by choosing what to read rather than in whatever text was last open.

The drawer SHALL NOT be opened until the restoration of the last reading session has settled — whether it restored a novel, found none to restore, or failed. Restoration walks the library directories, so opening the drawer before it settles would show the reader the library root and then replace it with an episode listing under their hands.

Restoration itself is unchanged: it selects the last-read episode, and the file listing opens positioned on the selected file. The reader therefore finds the drawer already resting on where they left off, and dismissing the drawer resumes reading without any further selection.

#### Scenario: A launch with a previous reading session
- **WHEN** the application launches and a previous reading session is restored
- **THEN** the drawer is opened only after the restoration has settled, showing the restored novel's episode listing with the last-read episode selected and scrolled into view

#### Scenario: A first launch with nothing to restore
- **WHEN** the application launches and there is no reading session to restore
- **THEN** the drawer is opened once that is established, showing the library root with nothing selected

#### Scenario: The drawer is not opened while restoration is still running
- **WHEN** the restoration of the last reading session has not yet settled
- **THEN** the drawer is closed, so the replacement of the listing is not shown to the reader

#### Scenario: A failed restoration still opens the drawer
- **WHEN** the restoration of the last reading session fails
- **THEN** the drawer is opened anyway, showing the library root, so a failure never leaves the reader without the file browser

### Requirement: Escape closes an open drawer before anything else
When the file browser drawer is open, the application SHALL treat Escape as a request to close that drawer, and SHALL NOT let the same press end a search session or stop speech. A second press is then handled as it would have been with no drawer open.

This ordering makes Escape act on whatever is in front of the reader. It does not apply while a text input holds focus, where Escape is left to that field as before.

The end drawer holding the search results is not covered by this rule. Dismissing it is itself the end of the search session, so closing it and ending the search are the same act rather than two presses; Escape therefore ends the search session as before, and the end drawer follows.

#### Scenario: Escape closes the drawer and leaves the search running
- **WHEN** the reader presses Escape with the file browser drawer open and a search session active
- **THEN** the drawer closes, and the search session remains active

#### Scenario: A second Escape ends the search
- **WHEN** the reader presses Escape again after the drawer has closed, with the search session still active
- **THEN** the search session ends as it does when no drawer is open

#### Scenario: Escape is unchanged when no drawer is open
- **WHEN** the reader presses Escape with no drawer open
- **THEN** an active search session is ended, and otherwise speech in progress is stopped

#### Scenario: Escape with only the search end drawer open ends the search
- **WHEN** the reader presses Escape in the narrow layout with the search end drawer open and the file browser drawer closed
- **THEN** the search session is ended and the end drawer closes with it, exactly as before this change
