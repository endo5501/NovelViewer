## ADDED Requirements

### Requirement: A marked word opens its popup on a touch tap
The summary popup SHALL be reachable from a pointer that does not hover. In both display modes, a tap on a marked word from a pointer kind that has no secondary button — touch and stylus — SHALL open the popup for that word, anchored at the tap position, showing the same content the hover trigger shows.

The distinction SHALL be made from the pointer's device kind rather than from the running platform, so that a tablet with a trackpad keeps the hover behaviour and a touchscreen desktop gains the touch behaviour. The hover trigger SHALL be unchanged for every pointer kind that hovers: the entry and exit handling, the ~150 ms grace period, and the popup's own `MouseRegion` SHALL behave exactly as before.

A mouse tap SHALL NOT open the popup. A mouse already reaches it by hovering, and a click on the text has an existing meaning in both modes that SHALL be preserved.

In vertical mode this trigger SHALL be ordered against the meanings a tap already carries. A tap inside the current selection SHALL open the selection context menu, as it does today. A tap that is not inside the selection but falls within a mark range SHALL open the popup. A tap that is neither SHALL clear the selection, as it does today.

In horizontal mode the tapped position SHALL be resolved through the selection the text widget itself reports for the tap, rather than through a separate layout measurement, so the resolved character is the one the platform's own hit test chose. That position names a boundary between two characters rather than a character, and the two are told apart by which side of the boundary the touch fell on, so that the last character of a marked word and the first character after it resolve differently. Where the reported position has been snapped to a word edge, a mark that ends at that edge SHALL still be resolved.

#### Scenario: Tapping a marked word in horizontal mode opens the popup
- **WHEN** the reader taps with a finger on an occurrence of the word "アリス" which has at least one cached snapshot for the active folder, in horizontal display mode
- **THEN** the popup SHALL appear near the tap position showing the default-selected snapshot's summary

#### Scenario: Tapping a marked character in vertical mode opens the popup
- **WHEN** the reader taps with a finger on a character whose enclosing mark range corresponds to the word "アリス", in vertical display mode, with no selection active
- **THEN** the popup SHALL appear near the tap position showing the default-selected snapshot's summary

#### Scenario: A stylus tap opens the popup
- **WHEN** a stylus taps a marked word in either display mode
- **THEN** the popup SHALL appear, as it does for a finger

#### Scenario: A mouse click on a marked word does not open the popup
- **WHEN** a mouse click lands on a marked word in either display mode
- **THEN** the popup SHALL NOT be opened by the click
- **AND** the click SHALL keep its existing meaning for that mode

#### Scenario: Tapping unmarked text opens nothing
- **WHEN** the reader taps with a finger on text that is not within any mark range
- **THEN** no popup SHALL appear

#### Scenario: The selection context menu wins over the popup in vertical mode
- **WHEN** the reader has selected text in vertical mode and taps with a finger inside the selected range, and that range covers a marked word
- **THEN** the selection context menu SHALL appear
- **AND** no popup SHALL appear

#### Scenario: Tapping a mark at a word edge in horizontal mode opens the popup
- **WHEN** the reader taps with a finger on a marked word in horizontal mode and the platform reports the tap position snapped to the edge of that word rather than a position inside it
- **THEN** the popup SHALL open for that word

#### Scenario: Tapping the character after a marked word opens nothing
- **WHEN** the reader taps with a finger on the character immediately after a marked word, which shares its position with the end of that word
- **THEN** no popup SHALL appear

#### Scenario: Tapping the last character of one of two adjacent marked words opens that word
- **WHEN** two marked words sit side by side and the reader taps with a finger on the last character of the first
- **THEN** the popup SHALL open for the first word, not the second

#### Scenario: Re-tapping the same word after dismissal opens it again
- **WHEN** the reader taps a marked word in horizontal mode, dismisses the popup, and taps the same word again without moving the finger to a different word first
- **THEN** the popup SHALL open again

#### Scenario: Hover behaviour is unchanged
- **WHEN** a mouse pointer enters a marked word, leaves it, and re-enters it
- **THEN** the popup SHALL appear, dismiss after the grace period, and reappear, exactly as before this trigger was added

### Requirement: A touch outside the popup dismisses it
While the popup is visible, a pointer-down from a pointer kind that has no secondary button — touch and stylus — that lands outside the popup's own bounds SHALL dismiss the popup. This is the counterpart of the pointer leaving the popup's `MouseRegion`, which a pointer that does not hover never does.

The mechanism SHALL NOT absorb the pointer event: whatever the reader touched SHALL still receive it, so the touch that dismisses the popup also does what it would otherwise have done, including opening the popup for a different marked word.

A pointer-down from a mouse SHALL be ignored, so that no dismissal behaviour on a hovering pointer changes.

A pointer-down SHALL NOT dismiss the popup while a popup-owned child overlay is open. The re-analysis dropdown's items float over the text without stopping a press from reaching it, so without this the touch that picks an item would take down the popup the menu belongs to before its handler ran. This is separate from the popup closing once the menu has closed, which it already does.

#### Scenario: Touching outside the popup dismisses it
- **WHEN** the popup is visible and the reader touches anywhere outside the popup's bounds
- **THEN** the popup SHALL be dismissed

#### Scenario: Touching the popup itself keeps it visible
- **WHEN** the popup is visible and the reader touches inside the popup's bounds, for example on the snapshot navigator
- **THEN** the popup SHALL remain visible
- **AND** the control under the touch SHALL respond as usual

#### Scenario: The dismissing touch still reaches what it landed on
- **WHEN** the popup is visible and the reader touches a control outside it, such as a toolbar button
- **THEN** the popup SHALL be dismissed
- **AND** the control SHALL be activated by the same touch

#### Scenario: Touching a different marked word switches the popup
- **WHEN** the popup is visible for the word "アリス" and the reader taps a marked occurrence of the word "ボブ"
- **THEN** the popup SHALL display the default-selected snapshot for "ボブ"

#### Scenario: A mouse press outside the popup does not dismiss it
- **WHEN** the popup is visible because a mouse pointer is inside it, and the mouse presses its primary button outside the popup
- **THEN** the dismissal SHALL be governed by the existing pointer-exit handling alone

#### Scenario: Touching a re-analysis dropdown item runs that analysis
- **WHEN** the popup's re-analysis dropdown is open and the reader touches one of its items
- **THEN** the selected re-analysis SHALL run
- **AND** the touch SHALL NOT be taken for a press on what the item covers, either as a dismissal or as a tap on a word beneath it

### Requirement: Scrolling in horizontal mode dismisses the popup
In horizontal display mode, a scroll the reader initiated SHALL dismiss the popup. The popup is anchored at a screen position computed when it opened, so text that scrolls out from under it leaves the popup pointing at nothing. Vertical mode already dismisses the popup on a page change and on the start of a drag selection; horizontal mode SHALL dismiss it on the reader's scroll for the same reason.

A scroll the application performed on the reader's behalf SHALL NOT dismiss the popup. The automatic scroll that follows the speech highlight is the case in point: the reader did not move the text, and the popup they opened SHALL survive it.

#### Scenario: Scrolling the text dismisses the popup
- **WHEN** the popup is visible in horizontal mode and the reader scrolls the text by any means they drive, including a drag, a fling, the scrollbar, or a wheel
- **THEN** the popup SHALL be dismissed

#### Scenario: Speech-following scroll does not dismiss the popup
- **WHEN** the popup is visible in horizontal mode and the viewer scrolls automatically to keep the speech highlight in view
- **THEN** the popup SHALL remain visible

## MODIFIED Requirements

### Requirement: Popup position adjusts for display mode
The hover popup SHALL be positioned relative to the pointer based on the active display mode so the popup does not obscure the natural reading flow. In horizontal mode the popup SHALL appear with its top-left corner offset 16 px right and 16 px below the pointer position. In vertical mode the popup SHALL appear with its bottom-left corner offset 16 px right and 16 px above the pointer position; if this placement would cause the popup to overflow the right edge of the screen, the horizontal anchor SHALL flip so the popup appears to the left of the pointer instead; if the placement would cause the popup to overflow the top edge of the screen, the vertical anchor SHALL flip so the popup appears below the pointer instead.

In horizontal mode the same edge handling SHALL apply, so that the popup stays on screen on a display narrow enough for the default placement to overflow it. If placing the popup to the right of the pointer would extend beyond the screen's right edge, the horizontal anchor SHALL flip so the popup appears to the left of the pointer; if placing it below the pointer would extend beyond the screen's bottom edge, the vertical anchor SHALL flip so the popup appears above the pointer. The resulting origin SHALL then be clamped so that it remains on screen even where neither flip can fit the popup. Where the screen has room for the default placement — which is the ordinary case on a desktop window — the placement SHALL be exactly as it was: 16 px right and 16 px below the pointer, with no flip and no clamp.

#### Scenario: Horizontal mode places popup down-right of pointer
- **WHEN** the popup is shown for a marked word in horizontal mode at pointer global position (P) with enough room to the right and below
- **THEN** the popup's top-left corner SHALL be at approximately (P.dx + 16, P.dy + 16)

#### Scenario: Horizontal mode flips horizontally near the right screen edge
- **WHEN** the popup is shown in horizontal mode at pointer global position (P) and placing the popup to the right would extend beyond the screen's right edge
- **THEN** the popup SHALL be placed to the left of the pointer instead

#### Scenario: Horizontal mode flips vertically near the bottom screen edge
- **WHEN** the popup is shown in horizontal mode at pointer global position (P) and placing the popup below would extend beyond the screen's bottom edge
- **THEN** the popup SHALL be placed above the pointer instead

#### Scenario: Horizontal mode keeps the popup origin on screen when no flip fits
- **WHEN** the popup is shown in horizontal mode on a screen too small for either placement to fit the popup
- **THEN** the popup's top-left corner SHALL be clamped to the screen, so the popup starts on screen rather than off it

#### Scenario: Vertical mode places popup up-right of pointer when screen permits
- **WHEN** the popup is shown for a marked character in vertical mode at pointer global position (P) with enough room to the right and above
- **THEN** the popup's bottom-left corner SHALL be at approximately (P.dx + 16, P.dy − 16) so the popup floats above and to the right of the pointer

#### Scenario: Vertical mode flips horizontally near the right screen edge
- **WHEN** the popup is shown in vertical mode at pointer global position (P) and placing the popup to the right would extend beyond the screen's right edge
- **THEN** the popup's right edge SHALL be placed to the left of the pointer instead (popup appears up-left of the pointer)

#### Scenario: Vertical mode flips vertically near the top screen edge
- **WHEN** the popup is shown in vertical mode at pointer global position (P) and placing the popup above would extend beyond the screen's top edge
- **THEN** the popup SHALL be placed below the pointer instead (popup appears down-right, mirroring the horizontal-mode placement)

### Requirement: Re-analysis dropdown on the popup
On a platform where LLM summary is available, the popup SHALL include a re-analysis control (e.g., a button labeled "再解析" with a dropdown indicator) in the top-right area of the popup. Activating the control SHALL open a dropdown menu containing two items:

1. "現在ページまで (Nファイル時点)" — where N is the numeric prefix of the currently viewed file (or its lexical rank when no numeric prefix exists). Selecting this item SHALL invoke the LLM analysis pipeline with `covered_up_to_episode=N` (equivalent to the "解析開始(ネタバレなし)" trigger).
2. "全話まで (Mファイル時点)" — where M is the highest numeric prefix in the folder. Selecting this item SHALL invoke the pipeline with `covered_up_to_episode=M` (equivalent to "解析開始(ネタバレあり)").

Each item SHALL append the localized suffix " (上書き)" when an existing snapshot row already matches the would-be `covered_up_to_episode`. Selecting an item that would overwrite SHALL proceed without a confirmation dialog (mirroring the existing context-menu re-analysis behavior). The popup itself SHALL remain visible while the re-analysis dropdown is open; the existing pointer grace period and `MouseRegion` handling SHALL be extended to cover the dropdown menu so that opening it does not cause the popup to dismiss.

Where LLM summary is unavailable, the control SHALL be absent while the rest of the popup keeps working: reading a summary stored earlier — by a desktop install whose novel folder was carried over — is not gated, only producing a new one. The popup is reachable on such a platform by a touch tap on the marked word, and also by hover wherever a hovering pointer is present, such as a tablet with a trackpad attached.

#### Scenario: Both items present with episode hints
- **WHEN** the popup is open while viewing "040_chapter.txt" in a folder whose highest-prefix file is "120_chapter.txt", and no snapshot currently exists at episodes 40 or 120
- **THEN** the re-analysis dropdown SHALL list "現在ページまで (40ファイル時点)" and "全話まで (120ファイル時点)" with no "(上書き)" suffix on either item

#### Scenario: Overwrite suffix when current-page snapshot already exists
- **WHEN** the popup is open while viewing "040_chapter.txt" and a snapshot at `covered_up_to_episode=40` already exists for the word
- **THEN** the dropdown item "現在ページまで (40ファイル時点)" SHALL be displayed with the "(上書き)" suffix

#### Scenario: Overwrite suffix when full-scope snapshot already exists
- **WHEN** the folder's highest-prefix file is "120_chapter.txt" and a snapshot at `covered_up_to_episode=120` already exists for the word
- **THEN** the dropdown item "全話まで (120ファイル時点)" SHALL be displayed with the "(上書き)" suffix

#### Scenario: Selecting an item triggers analysis without confirmation
- **WHEN** the user selects "現在ページまで (40ファイル時点) (上書き)"
- **THEN** the existing snapshot at `covered_up_to_episode=40` SHALL be overwritten by the new analysis result; no confirmation dialog SHALL be shown
- **AND** the standard analysis modal (with spinner and pipeline progress label) SHALL appear during the call

#### Scenario: Popup stays visible while the dropdown is open
- **WHEN** the user opens the re-analysis dropdown and the pointer is anywhere within the dropdown menu region
- **THEN** the popup SHALL NOT dismiss due to the pointer leaving the marked word range

#### Scenario: Closing the dropdown without selection returns to popup
- **WHEN** the user dismisses the dropdown without picking an item
- **THEN** the popup SHALL remain visible in its prior state (same selected snapshot)

#### Scenario: The control is absent where analysis is unavailable
- **WHEN** the popup opens on a platform where LLM summary is unavailable
- **THEN** no re-analysis control is present

#### Scenario: A stored summary is still readable where analysis is unavailable
- **WHEN** the popup opens on a platform where LLM summary is unavailable and a stored snapshot exists for the word
- **THEN** the snapshot's summary text and its episode label are displayed as usual
