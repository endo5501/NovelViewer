## ADDED Requirements

### Requirement: Generate all cancellation
The system SHALL provide a "中断" button in the dialog toolbar during bulk generation that immediately stops the TTS generation. When the user presses "中断", the system SHALL dispose the TTS Isolate to terminate any in-progress synthesis, rather than waiting for the current segment to complete. After cancellation, segments that were fully generated before cancellation SHALL be preserved. The system SHALL allow the user to continue using the dialog (single segment generation, bulk generation, playback) after cancellation by creating a new TTS Isolate on the next generation request.

#### Scenario: Cancel stops in-progress synthesis immediately
- **WHEN** the user presses "中断" while segment 5 of 10 is being synthesized (segments 0-4 already generated)
- **THEN** the TTS Isolate is disposed immediately, segments 0-4 retain their generated audio, segment 5 has no audio, and the dialog returns to idle state

#### Scenario: Generate after cancel reloads model
- **WHEN** the user presses "中断" during bulk generation and then clicks "再生成" on a segment
- **THEN** a new TTS Isolate is spawned, the model is loaded, and the segment is generated successfully

#### Scenario: Cancel button replaces generate all button
- **WHEN** bulk generation is in progress
- **THEN** the "全生成" button in the toolbar is replaced by a "中断" button

#### Scenario: Cancel button hidden when not generating
- **WHEN** bulk generation is not in progress
- **THEN** the "中断" button is not displayed and the "全生成" button is visible

### Requirement: Per-segment generation progress indicator
During bulk generation, the system SHALL indicate the currently generating segment by showing a spinner icon in that segment's status icon column. The system SHALL update the spinner to the next segment as each generation completes. Only one segment SHALL show the spinner at a time. The toolbar SHALL NOT display a global progress indicator (CircularProgressIndicator) during bulk generation.

#### Scenario: Spinner shown on generating segment during bulk generation
- **WHEN** bulk generation is processing segment 3
- **THEN** segment 3's status icon shows a CircularProgressIndicator spinner, and all other segments show their normal status icons (check for generated, circle for ungenerated)

#### Scenario: Spinner moves to next segment after completion
- **WHEN** segment 3 finishes generating during bulk generation and segment 5 is next (segment 4 already has audio)
- **THEN** segment 3's icon changes to a green check, and segment 5's icon changes to a spinner

#### Scenario: No global spinner in toolbar during bulk generation
- **WHEN** bulk generation is in progress
- **THEN** the toolbar does NOT display a CircularProgressIndicator; the only indication of generation progress is the per-segment spinner icon

#### Scenario: Spinner cleared after bulk generation completes
- **WHEN** all ungenerated segments have been processed
- **THEN** no segment shows a spinner icon, and the toolbar returns to showing the "全生成" button

## MODIFIED Requirements

### Requirement: Generate all ungenerated segments
The system SHALL provide a "全生成" button in the dialog toolbar that generates audio for all segments that currently have no audio_data. Generation SHALL proceed sequentially from the first ungenerated segment. The TTS model SHALL be loaded if not already loaded. Before generating each segment, the system SHALL notify the UI of the segment index being processed so that the per-segment progress indicator can be updated.

#### Scenario: Generate all ungenerated segments
- **WHEN** the user clicks "全生成" with segments 1 and 4 having no audio
- **THEN** segments 1 and 4 are generated in index order using their current text and ref_wav_path, and their status changes to "生成済み"

#### Scenario: Generate all when all segments already generated
- **WHEN** the user clicks "全生成" and all segments have audio
- **THEN** no generation occurs (nothing to generate)

#### Scenario: Per-segment notification during bulk generation
- **WHEN** bulk generation starts processing segment 4
- **THEN** the system notifies the UI with segmentIndex=4 before synthesis begins, enabling the per-segment progress indicator to update
