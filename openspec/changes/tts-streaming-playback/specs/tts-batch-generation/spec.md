## MODIFIED Requirements

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

### Requirement: Generation stops on page navigation
The system SHALL stop batch generation when the user navigates away from the current episode. Generated segments SHALL be preserved and the episode status SHALL be updated to "partial".

#### Scenario: Navigate away during generation
- **WHEN** the user selects a different episode while generation is in progress with 8 of 15 segments generated
- **THEN** generation is cancelled, the episode status is set to "partial", and all 8 generated segments remain in the database
