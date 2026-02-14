## ADDED Requirements

### Requirement: Swipe gesture page navigation
The system SHALL support horizontal swipe gestures to navigate between pages in vertical display mode. Swipe detection SHALL be implemented using `Listener` widget pointer events (`onPointerDown`/`onPointerUp`) at the `VerticalTextViewer` level, so that it does not participate in the Flutter gesture arena and does not interfere with the existing text selection `GestureDetector` in `VerticalTextPage`. The system SHALL track only a single pointer at a time by recording the pointer ID on pointer down and only evaluating swipe criteria on pointer up for the same pointer ID. A gesture SHALL be recognized as a swipe when ALL of the following conditions are met: the absolute horizontal displacement exceeds 50 pixels, the absolute horizontal displacement exceeds the absolute vertical displacement, and the horizontal velocity (absolute horizontal displacement divided by gesture duration) exceeds 200 pixels per second. When a swipe is detected, the system SHALL clear any active text selection by invoking `onSelectionChanged` with `null`. Swipe detection thresholds SHALL be defined as named constants to facilitate future tuning.

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
- **WHEN** the user performs a horizontal drag with velocity below 200 pixels per second
- **THEN** the gesture is not recognized as a swipe and text selection operates normally

#### Scenario: Short horizontal movement is not recognized as swipe
- **WHEN** the user performs a horizontal movement with displacement below 50 pixels
- **THEN** the gesture is not recognized as a swipe and text selection operates normally

#### Scenario: Primarily vertical drag is not recognized as swipe
- **WHEN** the user performs a drag where vertical displacement exceeds horizontal displacement
- **THEN** the gesture is not recognized as a swipe and text selection operates normally

#### Scenario: Swipe clears active text selection
- **WHEN** a swipe gesture is detected while text is selected
- **THEN** the active text selection is cleared

#### Scenario: Swipe does not interfere with text selection gestures
- **WHEN** the user performs a slow deliberate drag for text selection
- **THEN** the text selection operates normally without triggering page navigation

#### Scenario: Arrow key navigation continues to work alongside swipe
- **WHEN** the user presses left or right arrow keys in vertical mode with swipe support enabled
- **THEN** the arrow key page navigation works identically to the existing behavior
