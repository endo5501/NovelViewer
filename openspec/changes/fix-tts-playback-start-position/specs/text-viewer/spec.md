## MODIFIED Requirements

### Requirement: Text selection
The user SHALL be able to select text within the displayed content by click-and-drag. The system SHALL track the currently selected text and make it available for search functionality. In addition to the text itself, the system SHALL track the selection's start offset in plain-text coordinates — the coordinate space of the content after ruby markup has been replaced by its base text. Both values SHALL be exposed through a single selection state; when there is no selection, that state SHALL be null. Consumers that only need the text SHALL be able to read it without dealing with the offset.

A selection offset only addresses the content it was made in, so the system SHALL clear the selection state when the selected file changes. Neither viewer mode reports the selection going away on a content swap on its own, so clearing SHALL be driven by the file-change listener rather than relying on the selection widgets.

#### Scenario: User selects text
- **WHEN** the user clicks and drags over text in the center column
- **THEN** the selected text is highlighted

#### Scenario: Selected text is tracked
- **WHEN** the user selects text in the text viewer
- **THEN** the selected text value is stored in application state and accessible to other features

#### Scenario: Selection start offset is tracked
- **WHEN** the user selects text in horizontal mode starting at a position whose plain-text offset is 120
- **THEN** the stored selection state carries the offset 120 alongside the selected text

#### Scenario: Selection offset skips ruby markup
- **WHEN** the user selects text in horizontal mode positioned after three ruby-annotated words
- **THEN** the stored offset counts each ruby annotation as the length of its base text, and does not count the ruby markup or the ruby reading

#### Scenario: Selection is cleared
- **WHEN** the user clicks elsewhere without dragging or selects different text
- **THEN** the previously tracked selection state is updated accordingly

#### Scenario: Switching episodes drops the previous selection
- **WHEN** the user selects text in one episode and then navigates to a different file
- **THEN** the selection state becomes null, so the stale offset is not applied to the new content

#### Scenario: Stale offset never reaches playback
- **WHEN** the user selects a sentence near the end of one episode, navigates to the next episode, and starts TTS playback without selecting anything
- **THEN** playback begins from the first segment of the new episode, not from the offset recorded in the previous one

#### Scenario: Search consumes only the selected text
- **WHEN** the search shortcut reads the selection state to seed a query
- **THEN** it uses the selected text and is unaffected by the presence of the offset
