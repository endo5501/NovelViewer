## MODIFIED Requirements

### Requirement: Swipe gesture page navigation
The system SHALL support horizontal swipe gestures to navigate between pages in vertical display mode. Swipe detection SHALL be implemented within `VerticalTextPage`'s `GestureDetector` (`onPan*` handlers), sharing the same gesture recognizer that handles text selection. The swipe hit area SHALL be the whole content area of `VerticalTextViewer`, NOT the bounding box of the rendered text and NOT the inset area the text is laid out in: a swipe SHALL be recognized regardless of whether a character is painted under the pointer, and regardless of how close to the edge of the viewer it starts. The margin that insets the text SHALL therefore be applied INSIDE the `GestureDetector`, as required by the "Text margin lives inside the gesture area" requirement. The system SHALL use a gesture mode (`undecided`/`selecting`/`swiping`) to early-classify the user's intent based on the initial drag direction. On `onPanDown`, the system SHALL capture the true pointer-down position — in both global and page-local coordinates — and reset the gesture mode to `undecided`. On `onPanStart`, the system SHALL record the anchor character index, resolved from that recorded pointer-down position rather than from the position `onPanStart` reports, but SHALL NOT start visual text selection (deferred selection). On `onPanUpdate`, once the displacement from the start position exceeds 10 pixels (`_kGestureDecisionThreshold`), the system SHALL classify the gesture: if `|dx| > |dy|` the mode becomes `swiping` (no selection visual updates); otherwise the mode becomes `selecting` (deferred selection begins). On `onPanEnd`, if the mode is `swiping` or `undecided`, the system SHALL use `detectSwipeFromDrag` to determine if the gesture constitutes a swipe based on displacement and velocity from `DragEndDetails`; if the mode is `selecting`, the system SHALL notify the text selection result without attempting swipe detection. When velocity is available (fling detected, > 200 px/s), a swipe SHALL be recognized if absolute horizontal displacement exceeds 50 pixels (`kSwipeMinDistance`). When velocity is unavailable (desktop scenario where user stops before releasing, velocity ≈ 0), a swipe SHALL be recognized if absolute horizontal displacement exceeds 80 pixels (`kSwipeMinDistanceWithoutFling`). In both cases, the absolute horizontal displacement SHALL exceed the absolute vertical displacement. When a swipe is detected, the system SHALL clear any active text selection and invoke the `onSwipe` callback. `VerticalTextViewer` SHALL pass an `onSwipe` callback to `VerticalTextPage` to handle page navigation, to the outgoing page of a transition as well as the incoming one: the incoming page starts fully off-screen, so for the first part of the slide every pointer-down over the content area lands on the outgoing page, and a swipe there would otherwise be dropped. The swipe direction-to-page mapping SHALL follow the "content dragging" metaphor consistent with horizontal mode scrolling: a right swipe (finger moves left-to-right, dx > 0) SHALL advance to the next page, and a left swipe (finger moves right-to-left, dx < 0) SHALL return to the previous page. This mirrors horizontal mode where swiping up reveals content below; in vertical text mode, swiping right reveals content to the left (the reading direction). Swipe detection thresholds SHALL be defined as named constants to facilitate future tuning. Page transitions triggered by swipe SHALL be accompanied by a slide animation as defined in the page-transition-animation capability.

#### Scenario: Right swipe advances to next page
- **WHEN** the user performs a right swipe (positive horizontal displacement, finger moves left-to-right) that meets all swipe criteria in vertical mode
- **THEN** the display advances to the next page with a slide animation (content dragging metaphor: drag content rightward to reveal next content on the left)

#### Scenario: Left swipe returns to previous page
- **WHEN** the user performs a left swipe (negative horizontal displacement, finger moves right-to-left) that meets all swipe criteria in vertical mode
- **THEN** the display returns to the previous page with a slide animation

#### Scenario: Swipe during a page transition turns the page again
- **WHEN** the reader swipes while a slide animation is still running, anywhere over the content area
- **THEN** the swipe is recognized and the next page transition begins, as required by the page-transition-animation capability

#### Scenario: Swipe over an area with no text turns the page
- **WHEN** the user swipes over an area of the page where no character is painted, such as the empty left-hand region of a last page whose text does not fill the width
- **THEN** the page turns exactly as it would for a swipe performed over the text

#### Scenario: Right swipe on last page has no effect
- **WHEN** the user performs a right swipe on the last page in vertical mode
- **THEN** the display remains on the last page without any animation

#### Scenario: Left swipe on first page has no effect
- **WHEN** the user performs a left swipe on the first page in vertical mode
- **THEN** the display remains on the first page without any animation

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
- **THEN** the arrow key page navigation works identically with slide animation


#### Scenario: Swipe starting within the outer margin turns the page
- **WHEN** the user starts a swipe inside the outer margin of the viewer content area, closer to the edge than the text is laid out, and completes a gesture that meets all swipe criteria
- **THEN** the page turns exactly as it would for a swipe that started over the text

#### Scenario: Swipe starting at the very edge of the viewer turns the page
- **WHEN** the user starts a swipe on the first logical pixel column of the viewer content area, at either the left or the right edge, and completes a gesture that meets all swipe criteria
- **THEN** the page turns, because the gesture recognizer covers the content area edge to edge

## ADDED Requirements

### Requirement: Text margin lives inside the gesture area
The margin that insets the vertical text from the edges of the viewer content area SHALL be applied inside `VerticalTextPage`, between its `GestureDetector` and the alignment of the text, rather than outside `VerticalTextPage` in `VerticalTextViewer`. The `GestureDetector`, and therefore the render box of `VerticalTextPage` itself, SHALL cover the whole content area handed to the viewer, leaving no band along any edge in which a pointer reaches no gesture recognizer.

The character hit regions and the pointer positions SHALL remain in the same coordinate space after this margin is applied, so that a tap resolves to the same character it resolved to when the margin was applied outside the page: hit regions are measured relative to the page's outermost render box and therefore already account for the margin, and pointer local positions are reported relative to render boxes that coincide with that same outermost box.

The pagination constants that reserve room for this margin SHALL remain expressed against the full viewer constraints, since `LayoutBuilder` sits outside the margin and the pagination therefore does not depend on where the margin widget is placed.

Decorations painted over the page, such as the bookmark indicator, SHALL NOT consume pointer events. A stack hit test stops at the frontmost child that reports a hit, so a decoration that participates in hit testing would create a dead spot over the page beneath it.

#### Scenario: The page render box covers the full content area including its margin
- **WHEN** a vertical page is rendered inside the viewer
- **THEN** the render box of `VerticalTextPage` SHALL cover the whole content area the viewer was given, and the rendered text SHALL sit inset from its edges by the text margin

#### Scenario: Tap resolves to the same character with the margin inside the gesture area
- **WHEN** the user taps a specific character in vertical mode
- **THEN** the resolved character index SHALL be the character under the pointer, with no offset introduced by the margin

#### Scenario: Hover over the margin resolves to no character
- **WHEN** the pointer hovers over the margin area where no character is painted
- **THEN** the hit test SHALL resolve to no character, no mark enter SHALL be reported, and no error SHALL occur

#### Scenario: Pagination is unchanged by the margin placement
- **WHEN** a document is paginated in vertical mode
- **THEN** the number of pages and the characters on each page SHALL be identical to the result produced when the margin was applied outside `VerticalTextPage`

#### Scenario: Bookmark indicator does not block gestures beneath it
- **WHEN** the user starts a swipe over the area covered by the bookmark indicator on a page that has a bookmark
- **THEN** the gesture SHALL reach the page and the swipe SHALL turn the page
