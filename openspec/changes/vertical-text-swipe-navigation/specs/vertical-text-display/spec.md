## ADDED Requirements

### Requirement: Swipe gesture page navigation
The system SHALL support horizontal swipe gestures to navigate between pages in vertical display mode. Swipe detection SHALL be implemented within `VerticalTextPage`'s `GestureDetector` (`onPan*` handlers), sharing the same gesture recognizer that handles text selection. The system SHALL use a gesture mode (`undecided`/`selecting`/`swiping`) to early-classify the user's intent based on the initial drag direction. On `onPanDown`, the system SHALL capture the true pointer-down position and reset the gesture mode to `undecided`. On `onPanStart`, the system SHALL record the anchor character index but SHALL NOT start visual text selection (deferred selection). On `onPanUpdate`, once the displacement from the start position exceeds 10 pixels (`_kGestureDecisionThreshold`), the system SHALL classify the gesture: if `|dx| > |dy|` the mode becomes `swiping` (no selection visual updates); otherwise the mode becomes `selecting` (deferred selection begins). On `onPanEnd`, if the mode is `swiping` or `undecided`, the system SHALL use `detectSwipeFromDrag` to determine if the gesture constitutes a swipe based on displacement and velocity from `DragEndDetails`; if the mode is `selecting`, the system SHALL notify the text selection result without attempting swipe detection. When velocity is available (fling detected, > 200 px/s), a swipe SHALL be recognized if absolute horizontal displacement exceeds 50 pixels (`kSwipeMinDistance`). When velocity is unavailable (desktop scenario where user stops before releasing, velocity ≈ 0), a swipe SHALL be recognized if absolute horizontal displacement exceeds 80 pixels (`kSwipeMinDistanceWithoutFling`). In both cases, the absolute horizontal displacement SHALL exceed the absolute vertical displacement. When a swipe is detected, the system SHALL clear any active text selection and invoke the `onSwipe` callback. `VerticalTextViewer` SHALL pass an `onSwipe` callback to `VerticalTextPage` to handle page navigation. Swipe detection thresholds SHALL be defined as named constants to facilitate future tuning.

#### Scenario: Left swipe advances to next page
- **WHEN** the user performs a left swipe (negative horizontal displacement) that meets all swipe criteria in vertical mode
- **THEN** the display advances to the next page

#### Scenario: Right swipe returns to previous page
- **WHEN** the user performs a right swipe (positive horizontal displacement) that meets all swipe criteria in vertical mode
- **THEN** the display returns to the previous page

#### Scenario: Left swipe on last page has no effect
- **WHEN** the user performs a left swipe on the last page in vertical mode
- **THEN** the display remains on the last page

#### Scenario: Right swipe on first page has no effect
- **WHEN** the user performs a right swipe on the first page in vertical mode
- **THEN** the display remains on the first page

#### Scenario: Slow horizontal drag is not recognized as swipe
- **WHEN** the user performs a horizontal drag with velocity below 200 pixels per second and distance below 80 pixels
- **THEN** the gesture is not recognized as a swipe and text selection operates normally

#### Scenario: Short horizontal movement is not recognized as swipe
- **WHEN** the user performs a horizontal movement with displacement below 50 pixels (with velocity) or below 80 pixels (without velocity)
- **THEN** the gesture is not recognized as a swipe and text selection operates normally

#### Scenario: Primarily vertical drag is not recognized as swipe
- **WHEN** the user performs a drag where vertical displacement exceeds horizontal displacement
- **THEN** the gesture mode becomes `selecting` and text selection operates normally without attempting swipe detection

#### Scenario: Swipe clears active text selection
- **WHEN** a swipe gesture is detected while text is selected
- **THEN** the active text selection is cleared

#### Scenario: Desktop drag with pause before release triggers swipe
- **WHEN** the user drags horizontally more than 80 pixels and pauses before releasing the mouse button (velocity drops to zero)
- **THEN** the gesture is recognized as a swipe using the distance-only fallback threshold

#### Scenario: Horizontal drag does not show selection highlight
- **WHEN** the user performs a primarily horizontal drag (|dx| > |dy| after 10px displacement)
- **THEN** the gesture mode becomes `swiping` and no text selection highlight is displayed during the drag

#### Scenario: Text selection drag does not trigger swipe
- **WHEN** the user performs a primarily vertical or diagonal drag for text selection (|dy| >= |dx| after 10px displacement)
- **THEN** the gesture mode becomes `selecting` and swipe detection is not attempted at pan end

#### Scenario: Very short drag below decision threshold
- **WHEN** the user performs a drag with total displacement below 10 pixels before releasing
- **THEN** the gesture mode remains `undecided`, no text selection highlight is shown, and swipe detection is attempted but does not qualify due to insufficient distance

#### Scenario: Arrow key navigation continues to work alongside swipe
- **WHEN** the user presses left or right arrow keys in vertical mode with swipe support enabled
- **THEN** the arrow key page navigation works identically to the existing behavior
