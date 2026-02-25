## ADDED Requirements

### Requirement: Text highlight during batch generation
The system SHALL highlight the currently processing sentence on the text viewer during batch TTS audio generation. The highlight SHALL be updated at the start of each segment's synthesis (before synthesis begins), using the existing `ttsHighlightRangeProvider`. The highlight range SHALL be set based on the segment's text offset and text length.

#### Scenario: Highlight updates when segment synthesis begins
- **WHEN** the system begins synthesizing segment N (text_offset=42, text_length=18)
- **THEN** the TTS highlight range is set to TextRange(start: 42, end: 60) before synthesis starts

#### Scenario: Highlight visible on text viewer during generation
- **WHEN** the TTS highlight range is set during batch generation
- **THEN** the corresponding sentence is visually highlighted on the text viewer, identical to playback highlight

#### Scenario: Highlight cleared on generation complete
- **WHEN** batch generation completes successfully for all segments
- **THEN** the TTS highlight range is cleared (set to null)

#### Scenario: Highlight cleared on generation cancelled
- **WHEN** the user cancels batch generation
- **THEN** the TTS highlight range is cleared (set to null)

### Requirement: Auto page turn during batch generation
The system SHALL automatically navigate to the page containing the currently highlighted sentence during batch generation, reusing the existing auto page turn mechanism used during playback.

#### Scenario: Auto page turn when processing segment on different page
- **WHEN** the segment being processed is on a different page than the current display (in vertical text mode)
- **THEN** the viewer navigates to the page containing the highlighted text

#### Scenario: Auto scroll when processing segment off-screen
- **WHEN** the segment being processed is off-screen (in horizontal text mode)
- **THEN** the viewer scrolls to make the highlighted text visible

## MODIFIED Requirements

### Requirement: Generation progress tracking
The system SHALL expose generation progress via a Riverpod provider. Progress SHALL include the current segment index and total segment count. The UI SHALL display a progress bar and text showing "N/M文" during generation. The system SHALL also notify the UI of the current segment's text position (offset and length) at the start of each segment's synthesis via a separate callback, enabling text highlight and page navigation.

#### Scenario: Progress updates during generation
- **WHEN** the 5th of 15 sentences has been generated
- **THEN** the progress provider reports current=5, total=15

#### Scenario: Progress bar display
- **WHEN** generation is in progress at 5/15
- **THEN** the UI shows a progress bar at 33% and text "5/15文"

#### Scenario: Segment position notified at synthesis start
- **WHEN** the system begins synthesizing the 6th segment (text_offset=120, text_length=25)
- **THEN** the onSegmentStart callback is invoked with textOffset=120 and textLength=25 before synthesis begins
