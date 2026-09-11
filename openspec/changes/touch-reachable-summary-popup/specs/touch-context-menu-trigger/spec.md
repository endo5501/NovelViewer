## MODIFIED Requirements

### Requirement: The vertical viewer's selection menu opens on a touch tap inside the selection
In vertical display mode, a tap that lands inside the current selection SHALL open the selection context menu, anchored at the tap position, and SHALL leave the selection intact.

A tap that does not land inside the selection SHALL be resolved against the mark ranges of analysed words before it is treated as a tap on nothing. A tap that falls within a mark range SHALL open that word's summary popup and SHALL leave the selection intact, as specified by `llm-summary-hover-popup`. A tap that falls within neither the selection nor any mark range SHALL keep its existing meaning and clear the selection.

The order SHALL be selection, then mark, then clear. The selection comes first because it is what the reader has just built by hand: a tap inside it means to act on that selection, even where the selected text happens to be an analysed word.

This trigger SHALL apply only to a tap from a pointer that has no secondary button — touch and stylus. A tap already means "clear the selection", and that meaning SHALL be preserved for a mouse, so that a mouse click behaves exactly as it did before. The distinction SHALL be made from the pointer's device kind rather than from the running platform, so that a tablet with a trackpad keeps the pointer behaviour and a touchscreen desktop gains the touch behaviour.

A tap that lands in the gap between two columns SHALL be resolved to the nearest character within that gap's width, rather than being treated as landing outside the text. Nothing is painted in those gaps and they are as wide as the spacing between columns, so a finger aimed at a character lands in one often; treating that as a tap outside would destroy a selection the reader had just made. A tap further away than that SHALL still resolve to nothing, so that a tap out in the margin keeps clearing the selection. The same resolved character SHALL be used for the mark test, so a finger aimed at a marked character opens its popup even when it lands in the adjacent gap.

The gesture recognizers of the vertical viewer SHALL NOT be changed. In particular no long-press recognizer SHALL be added there: a long press accepted after its deadline forcibly removes the pan recognizer from the arena, which would abandon a selection drag that began with the finger held still.

#### Scenario: Tapping inside the selection opens the menu
- **WHEN** the reader has selected text in vertical mode and taps with a finger inside the selected range
- **THEN** the selection context menu SHALL appear at the tap position
- **AND** the selection SHALL remain

#### Scenario: Tapping inside a selection that covers an analysed word still opens the menu
- **WHEN** the reader has selected a range that includes a marked word and taps with a finger inside that range
- **THEN** the selection context menu SHALL appear
- **AND** no summary popup SHALL appear

#### Scenario: Tapping a marked word outside the selection opens its popup
- **WHEN** the reader taps with a finger on a character that falls within a mark range and outside any current selection
- **THEN** that word's summary popup SHALL appear
- **AND** the selection SHALL remain unchanged

#### Scenario: Tapping outside the selection and outside any mark clears it
- **WHEN** the reader taps with a finger outside the selected range on a character that is not within any mark range
- **THEN** the selection SHALL be cleared, as before

#### Scenario: Tapping with no selection and no mark clears nothing and opens nothing
- **WHEN** the reader taps with a finger while no text is selected, on a character that is not within any mark range
- **THEN** no menu SHALL appear
- **AND** no summary popup SHALL appear

#### Scenario: A stylus tap inside the selection opens the menu
- **WHEN** a stylus taps inside the selected range
- **THEN** the selection context menu SHALL appear, as it does for a finger

#### Scenario: A mouse click inside the selection still clears it
- **WHEN** a mouse click lands inside the selected range
- **THEN** the selection SHALL be cleared and no menu SHALL appear

#### Scenario: A mouse click on a marked word still clears the selection
- **WHEN** a mouse click lands on a character within a mark range
- **THEN** the selection SHALL be cleared and no summary popup SHALL be opened by the click

#### Scenario: A tap in the gap between two selected columns opens the menu
- **WHEN** the reader taps with a finger in the unpainted gap between two columns that are both inside the selection
- **THEN** the selection context menu SHALL appear
- **AND** the selection SHALL remain

#### Scenario: A tap in the gap beside a marked character opens its popup
- **WHEN** the reader taps with a finger in the unpainted gap next to a marked character, with no selection active
- **THEN** that word's summary popup SHALL appear

#### Scenario: A tap in the margin still clears the selection
- **WHEN** the reader taps with a finger well outside the text, further from any character than the width of a column gap
- **THEN** the selection SHALL be cleared and no menu SHALL appear

#### Scenario: Drag selection and swipe page turning are unaffected
- **WHEN** the reader drags to select, or swipes horizontally to turn the page, in vertical mode
- **THEN** both SHALL behave exactly as they did before this trigger was added
