## ADDED Requirements

### Requirement: Hover popup on marked characters in vertical mode
In vertical display mode, the text viewer SHALL display the hover popup over the text when the mouse pointer enters the screen region of any marked character (a character that falls inside a mark range derived from the active `markedWords` set, rendered with a sidebar line by `llm-summary`). The popup SHALL remain visible while the pointer continues to hover within the same mark range OR enters the popup widget itself; when the pointer transitions outside the mark range, into a different mark range, or leaves the text region entirely, the same grace period (~150 ms) defined for horizontal mode SHALL apply, allowing the pointer to travel into the popup to interact with controls such as the no-spoiler / spoiler toggle. The popup body, [なし|あり] toggle pill, reference-position warning, loading indicator, and non-selectable text behavior SHALL be identical to horizontal mode.

#### Scenario: Hover over a marked character shows popup in vertical mode
- **WHEN** the display mode is vertical, the user moves the mouse pointer onto a character whose enclosing mark range corresponds to the word "アリス" which has a cached summary for the active folder
- **THEN** a popup widget SHALL appear near the pointer position displaying the cached summary text for "アリス"
- **AND** the sidebar line mark on the character SHALL remain rendered

#### Scenario: Pointer moves within the same mark range keeps popup stable
- **WHEN** the popup is visible for word "アリス" in vertical mode and the user moves the pointer to another character that belongs to the same mark range for "アリス"
- **THEN** the popup SHALL remain visible without flicker or re-creation

#### Scenario: Pointer transitions to a different marked word switches popup
- **WHEN** the popup is visible for word "アリス" in vertical mode and the user moves the pointer onto a character belonging to a different mark range for the word "ボブ" which also has a cached summary
- **THEN** the popup SHALL update to display the cached summary for "ボブ"

#### Scenario: Pointer leaves marked character in vertical mode hides popup after grace period
- **WHEN** the popup is visible in vertical mode, the user moves the pointer off any marked character into unmarked text or empty area, and the pointer does NOT enter the popup widget within the grace period
- **THEN** the popup SHALL disappear after the grace period elapses

#### Scenario: Pointer enters popup before grace period elapses keeps it visible (vertical mode)
- **WHEN** the popup is visible in vertical mode and the user moves the pointer from a marked character into the popup widget within the grace period
- **THEN** the popup SHALL remain visible for as long as the pointer stays inside the popup
- **AND** the user SHALL be able to click controls inside the popup such as the no-spoiler / spoiler toggle pill

#### Scenario: Hover over unmarked text in vertical mode does not show popup
- **WHEN** the display mode is vertical and the user moves the pointer over text that is not within any mark range
- **THEN** no popup SHALL appear

#### Scenario: Drag selection in vertical mode hides popup
- **WHEN** the popup is visible in vertical mode and the user presses the primary mouse button to begin a drag selection
- **THEN** the popup SHALL be hidden before selection updates begin

#### Scenario: Page transition in vertical mode hides popup
- **WHEN** the popup is visible in vertical mode and the user triggers a page change (swipe, arrow key, or scroll wheel)
- **THEN** the popup SHALL be hidden as the page transition starts

### Requirement: Popup position adjusts for display mode
The hover popup SHALL be positioned relative to the pointer based on the active display mode so the popup does not obscure the natural reading flow. In horizontal mode the popup SHALL appear with its top-left corner offset 16 px right and 16 px below the pointer position. In vertical mode the popup SHALL appear with its bottom-left corner offset 16 px right and 16 px above the pointer position; if this placement would cause the popup to overflow the right edge of the screen, the horizontal anchor SHALL flip so the popup appears to the left of the pointer instead; if the placement would cause the popup to overflow the top edge of the screen, the vertical anchor SHALL flip so the popup appears below the pointer instead.

#### Scenario: Horizontal mode places popup down-right of pointer
- **WHEN** the popup is shown for a marked word in horizontal mode at pointer global position (P)
- **THEN** the popup's top-left corner SHALL be at approximately (P.dx + 16, P.dy + 16)

#### Scenario: Vertical mode places popup up-right of pointer when screen permits
- **WHEN** the popup is shown for a marked character in vertical mode at pointer global position (P) with enough room to the right and above
- **THEN** the popup's bottom-left corner SHALL be at approximately (P.dx + 16, P.dy − 16) so the popup floats above and to the right of the pointer

#### Scenario: Vertical mode flips horizontally near the right screen edge
- **WHEN** the popup is shown in vertical mode at pointer global position (P) and placing the popup to the right would extend beyond the screen's right edge
- **THEN** the popup's right edge SHALL be placed to the left of the pointer instead (popup appears up-left of the pointer)

#### Scenario: Vertical mode flips vertically near the top screen edge
- **WHEN** the popup is shown in vertical mode at pointer global position (P) and placing the popup above would extend beyond the screen's top edge
- **THEN** the popup SHALL be placed below the pointer instead (popup appears down-right, mirroring the horizontal-mode placement)

### Requirement: Popup hides on display mode switch
When the user changes the text display mode (horizontal ↔ vertical) while a popup is visible, the system SHALL hide the popup immediately. This prevents a popup whose position was computed for the previous mode's layout from lingering after the mode switch.

#### Scenario: Switching from horizontal to vertical hides an open popup
- **WHEN** the popup is visible in horizontal mode and the user switches the display mode to vertical
- **THEN** the popup SHALL be hidden before the new mode renders

#### Scenario: Switching from vertical to horizontal hides an open popup
- **WHEN** the popup is visible in vertical mode and the user switches the display mode to horizontal
- **THEN** the popup SHALL be hidden before the new mode renders

## REMOVED Requirements

### Requirement: Hover popup disabled in vertical mode
**Reason**: Replaced by new requirement "Hover popup on marked characters in vertical mode" which enables the popup in vertical mode using a single `MouseRegion` over the vertical text page combined with the existing per-character hit-region infrastructure. The user-facing constraint (no hover popup when reading vertically) is being removed; the popup widget itself is unchanged.
**Migration**: No user-facing migration needed. Vertical-mode users will see the popup behavior they previously saw only in horizontal mode. The sidebar-line mark rendering is preserved (it was unrelated to this requirement).
