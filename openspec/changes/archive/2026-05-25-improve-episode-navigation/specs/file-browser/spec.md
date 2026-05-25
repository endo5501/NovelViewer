## MODIFIED Requirements

### Requirement: File selection
The user SHALL be able to select a file from the list by tapping on it, and the selected file SHALL be visually highlighted with a high-contrast indicator suitable for both light and dark themes. The selected `ListTile` SHALL display:

- a background fill using `Theme.of(context).colorScheme.secondaryContainer`,
- a 4-pixel wide accent border on the leading (left) edge using `Theme.of(context).colorScheme.primary`,
- the title text rendered with `FontWeight.w600` (semibold).

These three visual treatments combine background tint, an edge accent, and weight emphasis so that the selected row remains identifiable independently of color perception or background contrast. Non-selected rows SHALL retain the default `ListTile` appearance.

#### Scenario: User selects a file
- **WHEN** the user taps on a file in the list
- **THEN** the file is highlighted with the secondaryContainer background fill, primary-color leading accent bar, and semibold title text

#### Scenario: User selects a different file
- **WHEN** the user taps on a different file while one is already selected
- **THEN** the new file receives the full highlight treatment, the previous highlight is removed, and the center column updates to show the new file's content

#### Scenario: Highlight remains visible in dark mode
- **WHEN** the application theme is dark mode and a file is selected
- **THEN** the secondaryContainer background, primary leading accent bar, and semibold title remain clearly distinguishable from non-selected rows

## ADDED Requirements

### Requirement: Auto-scroll to keep the selected file visible
The file list SHALL automatically scroll so that the currently selected file's `ListTile` is visible within the viewport whenever the selection changes to a file that is currently off-screen. The scroll SHALL be animated and SHALL position the selected row near the vertical center of the list (`alignment ≈ 0.5`). Auto-scroll SHALL only fire on selection changes (i.e., when `selectedFileProvider`'s value transitions to a new file path); it SHALL NOT fire on unrelated rebuilds, on directory changes that already reset the list, or when the same file is re-selected.

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
