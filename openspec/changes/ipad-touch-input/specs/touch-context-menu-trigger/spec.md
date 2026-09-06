## ADDED Requirements

### Requirement: A context menu is reachable without a secondary mouse button
Every context menu the application offers SHALL be reachable on a device that has no secondary mouse button. A menu whose only trigger is a secondary tap is unreachable on a tablet, and the operations behind it are then unavailable with no substitute.

The touch trigger SHALL open the same menu as the secondary tap: the same entries, in the same order, with the same handlers. No entry SHALL be added, withheld, or reordered because of how the menu was opened. Where a menu's entries are already gated by platform capability, that gating SHALL remain the only reason an entry is absent.

#### Scenario: Every context menu has a touch trigger
- **WHEN** the application is operated with touch alone
- **THEN** the file browser's novel and folder menu, the bookmark list's menu, and the vertical viewer's selection menu SHALL each be reachable

#### Scenario: The touch trigger opens the same menu as the secondary tap
- **WHEN** a context menu is opened by its touch trigger rather than by a secondary tap
- **THEN** the entries and their order SHALL be identical to those the secondary tap produces
- **AND** choosing an entry SHALL run the same handler

### Requirement: List items open their context menu on a long press
A list item that offers a context menu on a secondary tap SHALL also offer it on a long press. The menu SHALL be anchored at the position the press began.

This trigger SHALL NOT be restricted by pointer device kind. A long press carries no other meaning anywhere in the application, so adding it takes nothing away from a mouse user, and a single unconditional trigger is simpler to reason about and to test than one that branches.

The existing secondary tap SHALL continue to work unchanged.

#### Scenario: Long-pressing a novel folder opens its menu
- **WHEN** the reader long-presses a novel folder in the file browser at the library root
- **THEN** the same context menu the secondary tap produces SHALL appear at the press position

#### Scenario: Long-pressing a bookmark opens its menu
- **WHEN** the reader long-presses an item in the bookmark list
- **THEN** the same context menu the secondary tap produces SHALL appear at the press position

#### Scenario: A long press with a mouse opens the menu too
- **WHEN** a mouse pointer holds the primary button down on such a list item past the long-press threshold
- **THEN** the context menu SHALL appear, exactly as it does for a finger

#### Scenario: The secondary tap keeps working
- **WHEN** the reader secondary-taps a list item that now also responds to a long press
- **THEN** the context menu SHALL appear as before

### Requirement: A long press SHALL NOT be intercepted by a tooltip
Where a list item carries a tooltip, that tooltip SHALL NOT consume the long press. Flutter's `Tooltip` registers its own long-press recognizer for non-hovering pointer kinds and sits deeper in the tree than the item's gesture handler, so by default it wins the gesture arena and shows the tooltip instead of the menu.

The tooltip SHALL keep its hover behaviour on a pointer that hovers. Only its touch trigger is given up.

#### Scenario: Long-pressing the title of a novel opens the menu
- **WHEN** the reader long-presses directly on the title text of a novel folder — the part of the tile a tooltip covers
- **THEN** the context menu SHALL appear
- **AND** the tooltip SHALL NOT appear

#### Scenario: Hovering still shows the full name
- **WHEN** a mouse pointer hovers over a tile whose name is elided
- **THEN** the tooltip SHALL show the full name as before

### Requirement: The vertical viewer's selection menu opens on a touch tap inside the selection
In vertical display mode, a tap that lands inside the current selection SHALL open the selection context menu, anchored at the tap position, and SHALL leave the selection intact. A tap that lands outside the selection SHALL keep its existing meaning and clear the selection.

This trigger SHALL apply only to a tap from a touch pointer. A tap already means "clear the selection", and that meaning SHALL be preserved for every other pointer kind, so that a mouse click behaves exactly as it did before. The distinction SHALL be made from the pointer's device kind rather than from the running platform, so that a tablet with a trackpad keeps the pointer behaviour and a touchscreen desktop gains the touch behaviour.

The gesture recognizers of the vertical viewer SHALL NOT be changed. In particular no long-press recognizer SHALL be added there: a long press accepted after its deadline forcibly removes the pan recognizer from the arena, which would abandon a selection drag that began with the finger held still.

#### Scenario: Tapping inside the selection opens the menu
- **WHEN** the reader has selected text in vertical mode and taps with a finger inside the selected range
- **THEN** the selection context menu SHALL appear at the tap position
- **AND** the selection SHALL remain

#### Scenario: Tapping outside the selection clears it
- **WHEN** the reader taps with a finger outside the selected range
- **THEN** the selection SHALL be cleared, as before

#### Scenario: Tapping with no selection clears nothing and opens nothing
- **WHEN** the reader taps with a finger while no text is selected
- **THEN** no menu SHALL appear

#### Scenario: A mouse click inside the selection still clears it
- **WHEN** a mouse click lands inside the selected range
- **THEN** the selection SHALL be cleared and no menu SHALL appear

#### Scenario: Drag selection and swipe page turning are unaffected
- **WHEN** the reader drags to select, or swipes horizontally to turn the page, in vertical mode
- **THEN** both SHALL behave exactly as they did before this trigger was added
