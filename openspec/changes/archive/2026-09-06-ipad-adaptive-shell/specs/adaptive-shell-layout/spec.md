## ADDED Requirements

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

The default breakpoint SHALL be 800 logical pixels, the width the desktop build already restores no window smaller than, because below it the three-column layout was never guaranteed to fit. No minimum size is imposed on the native window, so a reader may make one narrower and receive the narrow layout there too.

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
- **THEN** the narrow layout is presented there as well, because the columns would crowd the body text at that width whatever the platform

### Requirement: The narrow layout moves the side panels into drawers
In the narrow layout the application SHALL present the left column as a `Drawer` and the right column as an `endDrawer`, and the text viewer SHALL occupy the full width of the body with no column dividers. The drawer holding the left column SHALL use the same width as the left column of the wide layout, so the panel is laid out identically in both layouts.

In the wide layout the three-column arrangement SHALL be unchanged.

#### Scenario: The narrow layout gives the whole body to the text viewer
- **WHEN** the home screen is rendered in the narrow layout
- **THEN** the body contains the text viewer and no column dividers, and neither the left column nor the right column is inside the body

#### Scenario: The left column is reachable through a drawer
- **WHEN** the drawer is opened in the narrow layout
- **THEN** the left column panel is displayed inside it, at the same width it has in the wide layout

#### Scenario: The wide layout is unchanged
- **WHEN** the home screen is rendered in the wide layout
- **THEN** the left column, the text viewer and — when the right column is visible — the right column are laid out in a row exactly as before, and the scaffold presents no drawer

### Requirement: Drawers open only from the app bar
The application SHALL disable the scaffold's edge-drag gestures for both drawers in the narrow layout. The vertical text viewer already interprets a horizontal drag as a page turn, so an edge drag that opened a drawer would take page turning away at exactly the edges of the screen. The app bar's buttons SHALL be the only way to open either drawer.

#### Scenario: An edge drag does not open a drawer
- **WHEN** the reader drags horizontally from the left or right edge of the screen in the narrow layout
- **THEN** no drawer opens, and the gesture is left to the viewer beneath

#### Scenario: The app bar opens the drawer
- **WHEN** the reader taps the app bar's drawer button in the narrow layout
- **THEN** the drawer opens

### Requirement: A drawer closes when it stops being useful
An open drawer SHALL be closed when the reader selects a file, so that the newly opened text is visible without a further dismissal. An open drawer SHALL also be closed when the layout changes from narrow to wide, so that no drawer is left open over a layout that no longer has one.

#### Scenario: Selecting a file closes the drawer
- **WHEN** the reader opens the drawer in the narrow layout and selects a file from any of its tabs
- **THEN** the drawer closes and the selected file is shown in the text viewer

#### Scenario: Widening the window closes the drawer
- **WHEN** a drawer is open and the display width grows past the breakpoint
- **THEN** the drawer is closed and the wide layout is displayed
