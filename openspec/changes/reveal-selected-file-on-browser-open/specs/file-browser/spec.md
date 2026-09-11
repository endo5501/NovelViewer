## MODIFIED Requirements

### Requirement: Auto-scroll to keep the selected file visible
The file list SHALL automatically scroll so that the currently selected file's `ListTile` is visible within the viewport whenever the selection changes to a file that is currently off-screen. The scroll SHALL be animated and SHALL position the selected row near the vertical center of the list (`alignment ≈ 0.5`). This requirement governs selection changes only (i.e., when `selectedFileProvider`'s value transitions to a new file path); it SHALL NOT fire on unrelated rebuilds, on directory changes that already reset the list, or when the same file is re-selected. Revealing the selected file when the list is first shown is governed by the "Reveal the selected file when the list is first shown" requirement, which is a separate trigger with its own, non-animated behaviour.

If the selected file is already visible within the viewport, the auto-scroll MAY be skipped or MAY perform a no-op `ensureVisible` call — the visible-row position MUST NOT change in a way that the user perceives as an unwanted jump.

#### Scenario: Selecting an off-screen file scrolls it into view
- **WHEN** the file list contains 200 files and the user selects file #150 while the viewport is showing files #1–#20
- **THEN** the list scrolls so that file #150's `ListTile` becomes visible near the center of the viewport

#### Scenario: Selecting a file already in view does not jump
- **WHEN** the file list viewport is currently showing files #45–#65 and the user selects file #50
- **THEN** the viewport does not perform a perceivable jump; file #50 is highlighted in place

#### Scenario: Re-selecting the same file does not trigger scroll
- **WHEN** file #50 is currently selected and the user taps it again
- **THEN** the file list does not perform an animated scroll

#### Scenario: Manual scrolling is not interrupted by unrelated rebuilds
- **WHEN** the user manually scrolls the file list to inspect a different region while their selected file remains unchanged
- **THEN** the file list does not auto-scroll back to the selected file due to unrelated provider rebuilds (e.g., TTS status updates, theme changes)

#### Scenario: External selection change scrolls the list
- **WHEN** the selection is changed by an action other than tapping the list (e.g., next-episode navigation from the text viewer), and the new file is currently off-screen
- **THEN** the file list scrolls so that the newly selected file's `ListTile` becomes visible

## ADDED Requirements

### Requirement: Reveal the selected file when the list is first shown
When the file list is first built after the file browser is mounted, it SHALL position itself so that the currently selected file's `ListTile` is within the viewport, near its vertical center, without the user scrolling. This SHALL happen at most once per mount of the file browser, and SHALL be applied without animation, so that the list already sits at that position on the frame the user first sees it.

This reveal SHALL be driven by the file browser itself, from the fact that it was mounted with a selection already in place. It SHALL NOT depend on knowing whether the browser is presented as a drawer, as a fixed column, or in any other arrangement, so that every path that rebuilds the browser — opening the navigation drawer in the narrow layout, and crossing the shell layout breakpoint by rotating the device or resizing the window — is covered by the same rule.

The reveal SHALL be skipped, leaving the list at its top, when no file is selected, and when the selected file does not belong to the directory the browser is currently showing.

The reveal SHALL NOT fire again for the lifetime of that mount. In particular, navigating into another directory while the browser stays mounted SHALL NOT scroll the new listing toward the selection carried over from the previous directory. Where the list sits when one listing replaces another is otherwise outside this requirement: a scroll position that survives a listing change is existing behaviour of the underlying list and is neither required nor forbidden here.

The reveal SHALL be evaluated against the listing the user actually sees, not against an empty or still-loading one: a build that shows a loading indicator or an empty-directory message SHALL NOT consume the once-per-mount reveal.

The reveal SHALL take effect in the first layout of the list rather than after it. A correction applied once the list has already been laid out composites one frame at the top before it lands, which is visible wherever the browser appears without an opening animation in front of it, and lasts as long as the next frame takes to arrive.

#### Scenario: Reopening the drawer shows the selected file
- **WHEN** the reader is on file #150 of a 200 file novel in the narrow layout, closes the file browser drawer, and opens it again
- **THEN** file #150's `ListTile` is visible near the center of the file list without the reader scrolling

#### Scenario: The first frame showing the list is already placed
- **WHEN** the file browser is mounted with an off-screen file already selected
- **THEN** the first frame that lays the list out already has the selected row inside the viewport, and nothing moves afterwards

#### Scenario: A selection change still animates
- **WHEN** the reader selects an off-screen file in a browser that is already showing a list
- **THEN** the list scrolls to it over time, as required by the "Auto-scroll to keep the selected file visible" requirement, rather than jumping

#### Scenario: Rotating the device shows the selected file
- **WHEN** the reader is on an off-screen file and rotates the device so that the shell crosses the layout breakpoint and the file browser is rebuilt
- **THEN** the selected file's `ListTile` is visible in the rebuilt file list

#### Scenario: No selection leaves the list at the top
- **WHEN** the file browser is mounted while no file is selected
- **THEN** the file list shows its first entries and does not scroll

#### Scenario: A selection from another directory leaves the list at the top
- **WHEN** the file browser is mounted showing a directory that does not contain the currently selected file
- **THEN** the file list shows its first entries and does not scroll

#### Scenario: Navigating into a directory does not reveal again
- **WHEN** the file browser has already revealed the selected file for this mount, the reader scrolls the list back to its first entry, and the reader then navigates into another directory whose listing also contains the selected file
- **THEN** the list stays at the first entry and does not scroll back toward the selected file

#### Scenario: A slow directory load still gets its reveal
- **WHEN** the file browser is mounted with a file already selected while the directory listing is still loading, and the listing arrives afterwards
- **THEN** the selected file's `ListTile` is visible once the listing is shown
