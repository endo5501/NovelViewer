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

### Requirement: Batch generation pipeline
The system SHALL generate audio for all sentences in the episode text sequentially using the TTS Isolate. For each sentence, the system SHALL: synthesize audio via `TtsIsolate`, convert the Float32List result to WAV bytes using `WavWriter`, and save the WAV BLOB to the `tts_segments` table. An episode record with status "generating" SHALL be created before generation begins. The episode status SHALL be updated to "completed" when all segments have been generated.

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
- **THEN** generation stops, the episode record and any partial segments are deleted, and an error is reported

### Requirement: Generation progress tracking
The system SHALL expose generation progress via a Riverpod provider. Progress SHALL include the current segment index and total segment count. The UI SHALL display a progress bar and text showing "N/M文" during generation.

#### Scenario: Progress updates during generation
- **WHEN** the 5th of 15 sentences has been generated
- **THEN** the progress provider reports current=5, total=15

#### Scenario: Progress bar display
- **WHEN** generation is in progress at 5/15
- **THEN** the UI shows a progress bar at 33% and text "5/15文"

### Requirement: Generation cancellation
The system SHALL support cancelling batch generation. When cancelled, the system SHALL stop the TTS Isolate, delete the episode record and all partial segments from the database, and return to the "no audio" state.

#### Scenario: Cancel button displayed during generation
- **WHEN** batch generation is in progress
- **THEN** a cancel button is displayed alongside the progress bar

#### Scenario: Cancel stops generation and cleans up
- **WHEN** the user presses the cancel button during generation
- **THEN** the TTS Isolate is stopped, the episode and all segments are deleted from the database, and the UI returns to showing the "読み上げ音声生成" button

### Requirement: Delete existing audio before regeneration
The system SHALL delete any existing audio data for the episode before starting a new batch generation. This ensures a clean start without leftover data from previous generations.

#### Scenario: Existing audio cleared on new generation
- **WHEN** the user presses "読み上げ音声生成" for an episode that already has audio data
- **THEN** the existing episode record and all segments are deleted before new generation begins

### Requirement: Generation stops on page navigation
The system SHALL stop batch generation and clean up when the user navigates away from the current episode. Partial data SHALL be deleted.

#### Scenario: Navigate away during generation
- **WHEN** the user selects a different episode while generation is in progress
- **THEN** generation is cancelled, partial data is deleted, and the TTS Isolate is stopped
