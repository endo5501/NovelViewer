## MODIFIED Requirements

### Requirement: Batch generation pipeline
The system SHALL generate audio for all sentences in the episode text sequentially using the TTS Isolate. For each sentence, the system SHALL: synthesize audio via `TtsIsolate`, convert the Float32List result to WAV bytes using `WavWriter`, and save the WAV BLOB to the `tts_segments` table. An episode record with status "generating" SHALL be created before generation begins. The episode status SHALL be updated to "completed" when all segments have been generated. The system SHALL support starting generation from a specified segment index, skipping already-generated segments. After each segment is stored, the system SHALL invoke an `onSegmentStored` callback with the segment index to notify consumers. The `start()` method SHALL accept an optional `instruct` parameter. When inserting new segments, the system SHALL store the `instruct` value used for synthesis in the segment's `memo` column.

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

#### Scenario: Instruct stored as memo in new segments
- **WHEN** batch generation runs with `instruct: "楽しげな口調で"` and generates segment 0
- **THEN** the inserted segment record has memo="楽しげな口調で"

#### Scenario: Batch generation without instruct
- **WHEN** batch generation runs without an instruct parameter
- **THEN** the inserted segment records have memo=NULL
