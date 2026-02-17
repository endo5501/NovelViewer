## ADDED Requirements

### Requirement: Mouse wheel page navigation
The system SHALL support mouse wheel (scroll) events to navigate between pages in vertical display mode. The `VerticalTextViewer` widget's `Listener` SHALL handle `PointerScrollEvent` via the `onPointerSignal` callback. A downward scroll (`scrollDelta.dy > 0`) SHALL advance to the next page, and an upward scroll (`scrollDelta.dy < 0`) SHALL return to the previous page. This mapping matches the horizontal mode convention where scrolling down reveals further content. Page transitions triggered by wheel events SHALL use the same slide animation as arrow key and swipe navigation (via `_changePage`). The system SHALL ignore wheel events while a page transition animation is in progress (`AnimationController.isAnimating`) to prevent unintended multi-page advancement from rapid scroll events.

#### Scenario: Wheel scroll down advances to next page
- **WHEN** the user scrolls the mouse wheel downward (positive `scrollDelta.dy`) in vertical mode
- **THEN** the display SHALL advance to the next page with a slide animation

#### Scenario: Wheel scroll up returns to previous page
- **WHEN** the user scrolls the mouse wheel upward (negative `scrollDelta.dy`) in vertical mode
- **THEN** the display SHALL return to the previous page with a slide animation

#### Scenario: Wheel scroll down on last page has no effect
- **WHEN** the user scrolls the mouse wheel downward while on the last page in vertical mode
- **THEN** the display SHALL remain on the last page without any animation

#### Scenario: Wheel scroll up on first page has no effect
- **WHEN** the user scrolls the mouse wheel upward while on the first page in vertical mode
- **THEN** the display SHALL remain on the first page without any animation

#### Scenario: Wheel events are ignored during page transition animation
- **WHEN** the user scrolls the mouse wheel while a page transition animation is in progress
- **THEN** the wheel event SHALL be ignored and no additional page transition SHALL be triggered

#### Scenario: Wheel navigation coexists with arrow key navigation
- **WHEN** the user alternates between mouse wheel scrolling and arrow key presses in vertical mode
- **THEN** both input methods SHALL trigger page transitions independently using the same underlying mechanism

#### Scenario: Wheel navigation coexists with swipe navigation
- **WHEN** the user alternates between mouse wheel scrolling and swipe gestures in vertical mode
- **THEN** both input methods SHALL trigger page transitions independently using the same underlying mechanism

#### Scenario: Non-scroll pointer signals are ignored
- **WHEN** a pointer signal event other than `PointerScrollEvent` is received (e.g., `PointerScaleEvent`)
- **THEN** the event SHALL be ignored and no page transition SHALL occur
