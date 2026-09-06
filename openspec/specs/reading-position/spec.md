# reading-position Specification

## Purpose
TBD - created by archiving change restore-reading-position. Update Purpose after archive.
## Requirements
### Requirement: Layout-independent body position
The system SHALL identify a reading position using a zero-based UTF-16 offset into the parsed body text, concatenating plain text and ruby base text while excluding ruby annotations and tags. Newlines SHALL retain their parsed representation. Positions SHALL resolve to valid displayed character boundaries and SHALL NOT split surrogate pairs or combining character sequences. Ruby positions that cannot be represented individually SHALL resolve to the start of the ruby base. The same coordinate contract SHALL be shared by horizontal and vertical viewers without OS-specific behavior.

#### Scenario: Ruby and non-BMP characters
- **WHEN** content containing ruby, newlines, non-BMP characters, and combining characters is measured by either viewer
- **THEN** the saved position SHALL refer to the corresponding body text boundary under the common coordinate contract
- **AND** WidgetSpan counts and vertical layout rune counts SHALL NOT be persisted as if they were body offsets

### Requirement: Capture and restore the visible body position
The system SHALL capture the first visible body line's start in horizontal mode and the current page's first body position in vertical mode using the actual layout. Restoration SHALL occur after content and layout are ready and SHALL make the saved position visible. A normal file selection matching the novel's saved file SHALL restore its position; other files without a position SHALL open at the start. Bookmarks SHALL remain independently managed.

#### Scenario: Horizontal wrapped text
- **WHEN** a user leaves a long wrapped paragraph and later reopens the saved file
- **THEN** its saved visible body location SHALL be visible again, including when the original source line spans many rendered lines

#### Scenario: Vertical page restoration
- **WHEN** a user leaves a vertical page and later reopens the saved file
- **THEN** the viewer SHALL display the page containing the saved body position

#### Scenario: Selecting an unsaved file
- **WHEN** the user selects a file different from the novel's saved file without an explicit navigation target
- **THEN** the viewer SHALL open at the beginning

### Requirement: Preserve the anchor across layout changes
The system SHALL preserve the current logical body anchor when font, font size, column spacing, viewport dimensions, or horizontal/vertical display mode changes. The new layout SHALL show that anchor. Repeated relayouts without reading movement SHALL NOT cumulatively shift the anchor toward earlier text.

#### Scenario: Resize and change display mode
- **WHEN** the user changes viewport width, font settings, or display mode while reading
- **THEN** the original body anchor SHALL remain visible after layout settles

#### Scenario: Repeated layout changes
- **WHEN** the user repeatedly changes orientation or display settings without moving through the text
- **THEN** the same logical anchor SHALL be retained across all changes

### Requirement: Periodic and lifecycle position persistence
The system SHALL submit changed visible positions for persistence at intervals no longer than two seconds while active, even during continuous scrolling. It SHALL also flush pending snapshots on file or novel changes, selection clearing, and lifecycle inactive, hidden, paused, or detached notifications. Unchanged positions SHALL NOT generate periodic writes. Positions SHALL be associated with their original novel, file, and content generation. Failures SHALL log WARNING through Logger('reading_progress') and SHALL NOT block reading. Sudden process termination SHALL recover the last committed snapshot; uncommitted positions are not guaranteed.

#### Scenario: Continuous scrolling
- **WHEN** the visible position keeps changing for longer than two seconds
- **THEN** dirty positions SHALL be submitted periodically without waiting indefinitely for scrolling to stop

#### Scenario: Leave a novel or background the app
- **WHEN** a pending position exists and the user leaves the file or the app receives a background-related lifecycle notification
- **THEN** the system SHALL flush that snapshot with the original novel and file identity

#### Scenario: No movement
- **WHEN** the app remains open with an unchanged position
- **THEN** periodic timers SHALL NOT change the stored timestamp

#### Scenario: Write failure
- **WHEN** a position write fails
- **THEN** a WARNING SHALL be logged, the failed save SHALL be dropped, and subsequent reading and save attempts SHALL remain usable

### Requirement: Explicit navigation and asynchronous ordering
Explicit bookmark/search targets and episode fromStart/fromEnd intents SHALL take priority over automatic restoration. Restoration SHALL be consumed once per request and canceled by later navigation or manual reading movement. Temporary initial layout positions SHALL NOT overwrite saved progress while restoration is pending. Delayed observations or writes from an earlier selection SHALL NOT overwrite newer progress. Pending writes SHALL NOT recreate history after novel deletion. TTS following SHALL NOT cause automatic restoration to reapply.

#### Scenario: Bookmark or search target
- **WHEN** a bookmark or search result opens a file with saved progress
- **THEN** the explicit target SHALL be displayed instead of the saved position

#### Scenario: Episode navigation
- **WHEN** the user navigates to the next or previous episode
- **THEN** next SHALL open at the start and previous SHALL open at the end regardless of saved progress

#### Scenario: Delayed restoration loses to user input
- **WHEN** the user selects another file or manually scrolls/pages while a restore is pending
- **THEN** the delayed restoration SHALL NOT change the newer selection or visible position

#### Scenario: Outgoing write finishes late
- **WHEN** the user rapidly switches from file A to B in the same novel while A has pending writes
- **THEN** the final row SHALL identify B with B's position and SHALL NOT be replaced by A

#### Scenario: Initial layout before restoration
- **WHEN** the viewer temporarily lays out the beginning while restoration is pending
- **THEN** that temporary position SHALL NOT replace the saved anchor

#### Scenario: Delete with pending persistence
- **WHEN** a novel is deleted while its position save is queued or executing
- **THEN** the deletion SHALL leave no reading progress row recreated by that save

#### Scenario: TTS following after restoration
- **WHEN** TTS moves the viewport after a reading position has been restored
- **THEN** automatic restoration SHALL NOT jump back to the former position

### Requirement: Validate saved positions against content
The system SHALL persist a hash of the common body text with the position. A missing hash or changed body hash SHALL restore the file at its beginning. With a matching hash, out-of-range offsets SHALL be clamped to valid body bounds and display boundaries. Empty content SHALL use offset zero. Missing files SHALL retain normal unselected browsing without throwing or guessing another file.

#### Scenario: Legacy progress
- **WHEN** a saved row has no body hash
- **THEN** the saved file SHALL open at the beginning and subsequent valid capture SHALL save its current body hash

#### Scenario: Modified content
- **WHEN** the current body hash differs from the stored hash
- **THEN** the file SHALL open at the beginning and the new snapshot SHALL replace the stale position after layout

#### Scenario: Invalid offset or empty body
- **WHEN** a matching-hash record has an invalid offset or the body is empty
- **THEN** restoration SHALL use a valid bounded position, or zero for empty content, without failing

#### Scenario: Saved file removed
- **WHEN** the saved file no longer exists during folder-entry restoration
- **THEN** the folder listing SHALL remain usable without automatic file selection or removal of the saved history

