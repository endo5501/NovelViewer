## MODIFIED Requirements

### Requirement: Vertical text selection by drag
The system SHALL allow the user to select text in vertical display mode by click-and-drag gesture. The selection SHALL follow the vertical reading direction (top-to-bottom within a column, right-to-left across columns). The selection range SHALL be determined by mapping the pointer position to character indices using actual rendered widget rectangles collected via `GlobalKey` and `RenderBox`. During drag updates, the system SHALL snap to the nearest character region when the pointer is between characters.

The rectangles SHALL be collected relative to `VerticalTextPage`'s own render box, so that they stay correct when that render box is larger than the rendered text and the text is aligned inside it. A pointer position SHALL be resolved against those rectangles without any additional coordinate correction.

A drag that begins over an area where no character is painted SHALL NOT start a selection, because no anchor character can be resolved. Such a drag SHALL still be eligible for swipe detection as defined in the vertical-text-display capability.

A tap without dragging SHALL clear the selection, except where a tap from a pointer with no secondary button (touch or stylus) lands inside the current selection, which opens the selection context menu and leaves the selection intact. Resolving where such a tap landed SHALL snap to the nearest character within the width of a column gap, so that the unpainted gap between two selected columns counts as inside the selection; beyond that distance the tap SHALL resolve to nothing and so still clear. This SHALL hold for the empty area of the page as well: a tap there is farther than a column gap from any character, so it resolves to nothing and clears the selection. The gesture recognizers used here SHALL NOT be changed to support that: no long-press recognizer SHALL be added, because a long press accepted after its deadline forcibly removes the pan recognizer from the gesture arena and would abandon a selection drag that began with the finger held still.

#### Scenario: User selects text by dragging in vertical mode
- **WHEN** the user clicks and drags over characters in vertical display mode
- **THEN** the characters within the drag range are visually highlighted with a selection color

#### Scenario: Selection follows vertical reading order
- **WHEN** the user drags from a character in the right column to a character in the left column
- **THEN** all characters between the start and end positions are selected following top-to-bottom, right-to-left order

#### Scenario: Selection within a single column
- **WHEN** the user drags vertically within a single column
- **THEN** only the characters between the start and end positions within that column are selected

#### Scenario: Selection hit testing is unaffected by the page render box growing
- **WHEN** the user selects text on a page whose text occupies only part of the available width, so the rendered text sits at the top-right of a larger render box
- **THEN** the characters under the pointer are selected exactly as they are on a page whose text fills the width

#### Scenario: A drag starting over empty area starts no selection
- **WHEN** the user starts a primarily vertical drag from an area of the page where no character is painted
- **THEN** no selection is started and no selection highlight is displayed

#### Scenario: Tap clears existing selection
- **WHEN** the user taps without dragging outside the selected range while a selection exists
- **THEN** the selection is cleared

#### Scenario: A tap on the empty area of the page clears the selection
- **WHEN** the user taps an area of the page where no character is painted while a selection exists
- **THEN** the selection is cleared

#### Scenario: A mouse click inside the selection clears it
- **WHEN** the user clicks with a mouse inside the selected range
- **THEN** the selection is cleared

#### Scenario: A touch tap inside the selection does not clear it
- **WHEN** the user taps with a finger inside the selected range
- **THEN** the selection is retained
