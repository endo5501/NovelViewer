## ADDED Requirements

### Requirement: The narrow layout fits a portrait phone
The application SHALL lay out without overflow on a portrait phone display of 393 by 852 logical pixels, the size of an iPhone 16, with that display's safe-area insets applied. This SHALL hold for the home screen in the narrow layout, with and without an open file, for both drawers when open, for every dialog the application presents, and for every tab of the settings dialog.

The rule that decides the layout SHALL NOT change for this: the phone is narrower than the breakpoint and so receives the narrow layout, as a portrait iPad mini already does. What the phone adds is a width at which content sized for a tablet or a desktop window no longer fits, so where a surface would exceed the display, it SHALL shrink or scroll to fit rather than overflow. On a wider display each surface SHALL keep the size it has today.

The app bar SHALL keep every action it offers at that width and SHALL leave the title a visible share of the bar, truncated with an ellipsis rather than pushed out.

#### Scenario: The home screen fits a portrait phone
- **WHEN** the home screen is rendered at 393 by 852 logical pixels with the phone's safe-area insets, with no file open and again with a file open
- **THEN** no layout overflow is reported

#### Scenario: Every dialog fits a portrait phone
- **WHEN** each dialog the application presents is opened at 393 by 852 logical pixels
- **THEN** no layout overflow is reported, and the dialog's actions are reachable

#### Scenario: Every settings tab fits a portrait phone
- **WHEN** the settings dialog is opened at 393 by 852 logical pixels and each of its tabs is selected
- **THEN** no layout overflow is reported

#### Scenario: The app bar keeps its actions and its title
- **WHEN** the home screen is rendered at 393 by 852 logical pixels with a long novel title
- **THEN** every app bar action is present and the title is shown truncated rather than hidden

#### Scenario: A wide display keeps today's sizes
- **WHEN** a dialog is opened on a display wide and tall enough for its current size
- **THEN** it is presented at the size it has today
