### Requirement: Batch audio generation trigger
The system SHALL provide a "読み上げ音声生成" button in the text viewer panel when no audio exists for the current episode. Pressing this button SHALL start batch generation of audio for all sentences in the current episode's text content.

#### Scenario: Show generation button when no audio exists
- **WHEN** the user views an episode that has no TTS audio in the database
- **THEN** a "読み上げ音声生成" button is displayed

#### Scenario: Hide generation button when audio exists
- **WHEN** the user views an episode that has completed TTS audio in the database
- **THEN** the generation button is not displayed; playback controls are shown instead

#### Scenario: Start generation on button press
- **WHEN** the user presses the "読み上げ音声生成" button
- **THEN** batch audio generation begins for all sentences in the current episode

## Requirements

### Requirement: Batch generation pipeline
The system SHALL generate audio for all sentences in the episode text sequentially using the TTS Isolate. For each sentence, the system SHALL: synthesize audio via `TtsIsolate`, convert the Float32List result to WAV bytes using `WavWriter`, and save the WAV BLOB to the `tts_segments` table. An episode record with status "generating" SHALL be created before generation begins. The episode status SHALL be updated to "completed" when all segments have been generated. The system SHALL support starting generation from a specified segment index, skipping already-generated segments. After each segment is stored, the system SHALL invoke an `onSegmentStored` callback with the segment index to notify consumers.

#### Scenario: Generate all sentences sequentially
- **WHEN** batch generation starts for an episode with 15 sentences
- **THEN** the system generates audio for each sentence one by one, saving each to the database as it completes

#### Scenario: Episode status transitions during generation
- **WHEN** batch generation starts
- **THEN** the episode status is "generating" until all segments are saved, then becomes "completed"

#### Scenario: TTS model loaded before generation
- **WHEN** batch generation starts
- **THEN** the TTS model is loaded in the Isolate using the configured model directory before the first sentence is synthesized

#### Scenario: Synthesis error during generation
- **WHEN** TTS synthesis fails for a sentence during batch generation
- **THEN** generation stops, the episode status is updated to "partial", generated segments are preserved, and an error is reported

#### Scenario: Resume generation from segment index
- **WHEN** generation starts with startSegmentIndex=5 for an episode with 15 sentences
- **THEN** the system skips segments 0-4 and begins generating from segment 5

#### Scenario: Segment stored notification
- **WHEN** segment 3 is successfully generated and stored in the database
- **THEN** the onSegmentStored callback is invoked with segmentIndex=3

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

### Requirement: Generation cancellation
The system SHALL support cancelling batch generation. When cancelled, the system SHALL stop the TTS Isolate and update the episode status to "partial". Generated segments SHALL be preserved in the database. The system SHALL NOT delete the episode record or segments on cancellation.

#### Scenario: Cancel button displayed during generation
- **WHEN** batch generation is in progress
- **THEN** a cancel button is displayed alongside the progress bar

#### Scenario: Cancel stops generation and preserves data
- **WHEN** the user presses the cancel button during generation after 5 of 15 segments have been generated
- **THEN** the TTS Isolate is stopped, the episode status is set to "partial", and all 5 generated segments remain in the database

### Requirement: Delete existing audio before regeneration
The system SHALL delete existing audio data for the episode only when the text content has changed (detected via text hash mismatch). If the text has not changed and a partial or completed episode exists, the system SHALL reuse existing data.

#### Scenario: Existing audio cleared when text changed
- **WHEN** generation is requested for an episode whose stored text_hash does not match the current text
- **THEN** the existing episode record and all segments are deleted before new generation begins

#### Scenario: Existing audio preserved when text unchanged
- **WHEN** generation is requested for an episode whose stored text_hash matches the current text
- **THEN** the existing episode data is reused and generation resumes from the first missing segment

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

### Requirement: Generation stops on page navigation
The system SHALL stop batch generation when the user navigates away from the current episode. Generated segments SHALL be preserved and the episode status SHALL be updated to "partial".

#### Scenario: Navigate away during generation
- **WHEN** the user selects a different episode while generation is in progress with 8 of 15 segments generated
- **THEN** generation is cancelled, the episode status is set to "partial", and all 8 generated segments remain in the database

### Requirement: Ruby text used for batch TTS synthesis
The system SHALL use ruby text (furigana from `<rt>` elements) instead of base text when preparing text segments for batch TTS audio generation. When splitting episode text into sentences, the text segmenter SHALL replace each `<ruby>` block with the content of its `<rt>` element, ensuring the TTS engine synthesizes audio using the author-intended pronunciation.

#### Scenario: Batch generation uses ruby text for synthesis
- **WHEN** batch generation processes the text `<ruby>魔法杖職人<rt>ワンドメーカー</rt></ruby>は言った。`
- **THEN** the TTS engine receives "ワンドメーカーは言った。" as the sentence to synthesize

#### Scenario: Segment text in database reflects ruby reading
- **WHEN** a segment is generated from text containing `<ruby>異世界<rt>いせかい</rt></ruby>へ。`
- **THEN** the segment stored in the `tts_segments` table has text "いせかいへ。"

#### Scenario: Edit screen displays ruby reading text
- **WHEN** the TTS edit screen shows segments generated from ruby-containing text
- **THEN** each segment displays the ruby text (furigana) rather than the base text (kanji)
