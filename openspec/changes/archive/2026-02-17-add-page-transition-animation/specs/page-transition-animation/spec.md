## ADDED Requirements

### Requirement: Page transition slide animation
The system SHALL animate page transitions in vertical text display mode using a horizontal slide effect. When navigating to the next page, the outgoing page SHALL slide from its current position to the right (positive X direction), and the incoming page SHALL slide in from the left. When navigating to the previous page, the outgoing page SHALL slide from its current position to the left (negative X direction), and the incoming page SHALL slide in from the right. Both the outgoing and incoming pages SHALL be visible simultaneously during the animation using a Stack layout. The slide offset SHALL be proportional to the widget's width (using `SlideTransition` with `Offset` in widget-size units). The animation SHALL be driven by an `AnimationController` managed in `VerticalTextViewer`.

#### Scenario: Next page transition slides right
- **WHEN** the user navigates to the next page (via left arrow key or right swipe)
- **THEN** the current page SHALL slide out toward the right and the new page SHALL slide in from the left

#### Scenario: Previous page transition slides left
- **WHEN** the user navigates to the previous page (via right arrow key or left swipe)
- **THEN** the current page SHALL slide out toward the left and the new page SHALL slide in from the right

#### Scenario: Both pages visible during transition
- **WHEN** a page transition animation is in progress
- **THEN** both the outgoing page and the incoming page SHALL be simultaneously visible within the display area

### Requirement: Animation timing parameters
The page transition animation SHALL have a duration of 250 milliseconds and SHALL use the `Curves.easeInOut` curve for natural acceleration and deceleration. These values SHALL be defined as named constants to facilitate future tuning.

#### Scenario: Animation completes in 250ms
- **WHEN** a page transition animation starts
- **THEN** the animation SHALL complete in 250 milliseconds

#### Scenario: Animation uses easeInOut curve
- **WHEN** a page transition animation is in progress
- **THEN** the slide position SHALL follow the `Curves.easeInOut` curve, accelerating at the start and decelerating at the end

### Requirement: Rapid navigation handling
When a new page navigation is triggered while a transition animation is still in progress, the system SHALL immediately complete the current animation (snap to final state) and then start a new animation for the newly requested page transition. The system SHALL NOT queue navigation requests or ignore them.

#### Scenario: Arrow key pressed during animation
- **WHEN** the user presses an arrow key while a page transition animation is in progress
- **THEN** the current animation SHALL immediately snap to its final state and a new transition animation SHALL begin for the newly requested page

#### Scenario: Swipe during animation
- **WHEN** the user performs a swipe gesture while a page transition animation is in progress
- **THEN** the current animation SHALL immediately snap to its final state and a new transition animation SHALL begin for the newly requested page

#### Scenario: Key repeat during animation
- **WHEN** the user holds down an arrow key generating repeated key events during animation
- **THEN** each key repeat event SHALL cause the current animation to snap and a new animation to begin, allowing fluid multi-page navigation

### Requirement: Animation cancellation on layout change
When the display area is resized (e.g., window resize) while a page transition animation is in progress, the system SHALL immediately cancel the animation and display the current page without animation. This prevents visual artifacts from mismatched layout calculations between the outgoing and incoming pages.

#### Scenario: Window resize during animation
- **WHEN** the application window is resized while a page transition animation is in progress
- **THEN** the animation SHALL be immediately cancelled and the current page SHALL be displayed without animation

### Requirement: No animation at page boundaries
When the user attempts to navigate beyond the first or last page, no animation SHALL be triggered. The display SHALL remain on the current page without any visual effect.

#### Scenario: Next page on last page
- **WHEN** the user attempts to navigate to the next page while on the last page
- **THEN** no animation SHALL be triggered and the display SHALL remain on the last page

#### Scenario: Previous page on first page
- **WHEN** the user attempts to navigate to the previous page while on the first page
- **THEN** no animation SHALL be triggered and the display SHALL remain on the first page
