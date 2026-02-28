## Purpose

TTS edit dialog for per-segment audio editing, playback, regeneration, and management within the text viewer.

## Requirements

### Requirement: TTS edit dialog access
The system SHALL provide a button in the TTS controls area (bottom-right of the text viewer panel) to open the TTS edit dialog. The button SHALL only be visible when a TTS model directory is configured and an episode file is selected.

#### Scenario: Open edit dialog from TTS controls
- **WHEN** the user clicks the edit button in the TTS controls area while an episode is selected
- **THEN** the TTS edit dialog opens showing all segments for the current episode

#### Scenario: Edit button hidden when no model configured
- **WHEN** the TTS model directory is not configured
- **THEN** the edit button SHALL NOT be displayed in the TTS controls area

### Requirement: Segment list display
The system SHALL display all segments of the current episode as a scrollable list in the TTS edit dialog. Segments SHALL be obtained by running `TextSegmenter` on the original episode text file, then merging with existing `tts_segments` records by `segment_index`. For segments with existing DB records, the DB values (text, ref_wav_path, memo) SHALL be displayed. For segments without DB records, the original text from `TextSegmenter` SHALL be displayed.

#### Scenario: Display segments for episode with no prior edits
- **WHEN** the edit dialog opens for an episode with no existing `tts_segments` records
- **THEN** all segments show the original text from `TextSegmenter`, status "未生成", and default reference audio

#### Scenario: Display segments for episode with existing audio
- **WHEN** the edit dialog opens for an episode with some segments already generated
- **THEN** segments with `audio_data` show status "生成済み" and their stored text (which may differ from the original), segments without records show original text and status "未生成"

#### Scenario: Display segments for episode with edited but ungenerated segments
- **WHEN** the edit dialog opens for an episode where the user previously edited text but did not regenerate
- **THEN** the edited text from DB is displayed and status shows "未生成" (since audio_data is NULL)

### Requirement: Segment row columns
Each segment row SHALL display the following columns: generation status indicator (未生成/生成済み/生成中), editable text field, reference audio selector, memo text field, play button, regenerate button, and reset button.

#### Scenario: Segment row displays all columns
- **WHEN** the edit dialog displays a segment
- **THEN** the row contains a status indicator, text field, reference audio dropdown, memo field, play button, regenerate button, and reset button

### Requirement: Segment text editing
The system SHALL allow editing the text field of each segment. Editing the text SHALL persist the change to the `tts_segments` table in the database when the text field loses focus or the user presses Enter. If no DB record exists for the segment, a new record SHALL be created with `audio_data` set to NULL. If a DB record with `audio_data` exists, the `audio_data` and `sample_count` SHALL be set to NULL (deleted) upon text change, and the segment status SHALL change to "未生成".

#### Scenario: Edit text of ungenerated segment without DB record
- **WHEN** the user edits the text of a segment that has no DB record and confirms (blur or Enter)
- **THEN** a new `tts_segments` record is created with the edited text, audio_data=NULL, and the segment status shows "未生成"

#### Scenario: Edit text of generated segment
- **WHEN** the user edits the text of a segment that has generated audio and confirms
- **THEN** the text is updated in DB, audio_data and sample_count are set to NULL, and the segment status changes to "未生成"

#### Scenario: Edit text of already-edited segment
- **WHEN** the user edits the text of a segment that was previously edited (DB record exists, audio_data=NULL) and confirms
- **THEN** the text is updated in DB and the segment remains "未生成"

### Requirement: Per-segment reference audio selection
Each segment SHALL have a reference audio selector defaulting to the global reference audio from settings. The user SHALL be able to change the reference audio for individual segments. The available options SHALL include "設定値" (use global setting), all audio files from the voices directory, and "なし" (no reference audio). If a previously selected reference audio file no longer exists on disk, the selector SHALL display "無し" and treat the segment as having no reference audio.

#### Scenario: Default reference audio from settings
- **WHEN** the edit dialog opens and a segment has no per-segment ref_wav_path set
- **THEN** the reference audio selector shows "設定値" indicating the global setting will be used

#### Scenario: Change reference audio for a segment
- **WHEN** the user selects a different reference audio file for a segment
- **THEN** the ref_wav_path is persisted to the segment's DB record immediately

#### Scenario: Reference audio file deleted from disk
- **WHEN** a segment's ref_wav_path points to a file that no longer exists on disk
- **THEN** the selector displays "無し" and generation SHALL use no reference audio

### Requirement: Segment memo field
Each segment SHALL have an editable memo text field. Memo content SHALL be persisted to the `tts_segments.memo` column when the field loses focus or the user presses Enter.

#### Scenario: Add memo to a segment
- **WHEN** the user types a memo for a segment and the field loses focus
- **THEN** the memo is persisted to the segment's DB record

### Requirement: Segment preview playback
The system SHALL allow playing a single segment's audio via the play button on each row. The play button SHALL only be enabled when the segment has generated audio (audio_data is not NULL).

#### Scenario: Play a generated segment
- **WHEN** the user clicks the play button on a segment with generated audio
- **THEN** the segment's audio plays as a preview within the edit dialog

#### Scenario: Play button disabled for ungenerated segment
- **WHEN** a segment has no generated audio (audio_data is NULL)
- **THEN** the play button is disabled

### Requirement: Single segment regeneration
The system SHALL allow regenerating a single segment's audio via the regenerate button. Regeneration SHALL use the segment's current text and ref_wav_path (resolving "設定値" to the actual global setting). The TTS model SHALL be loaded on the first regeneration request within the dialog session and kept loaded until the dialog is closed. During generation, the segment status SHALL show "生成中".

#### Scenario: Regenerate a single segment
- **WHEN** the user clicks the regenerate button on a segment
- **THEN** the TTS model is loaded (if not already), the segment's audio is generated from the current text and ref_wav_path, audio_data is stored in DB, and the status changes to "生成済み"

#### Scenario: Regenerate uses edited text
- **WHEN** the user has edited the text to "山奥のいっけんや" and clicks regenerate
- **THEN** the TTS engine receives "山奥のいっけんや" as input and generates audio accordingly

#### Scenario: Model stays loaded for subsequent regenerations
- **WHEN** the user regenerates segment 3, then regenerates segment 7
- **THEN** the TTS model is loaded once for segment 3 and reused for segment 7 without reloading

#### Scenario: Regenerate with per-segment reference audio
- **WHEN** the user has set a specific reference audio for a segment and clicks regenerate
- **THEN** the TTS engine uses that segment's reference audio, not the global setting

### Requirement: Segment reset
The system SHALL allow resetting a segment via the reset button. Resetting SHALL restore the segment's text to the original text from `TextSegmenter`, delete the audio_data (set to NULL), and clear the memo. The ref_wav_path SHALL also be reset to NULL (meaning "use global setting").

#### Scenario: Reset an edited segment with audio
- **WHEN** the user clicks the reset button on a segment with edited text and generated audio
- **THEN** the text is restored to the original from the source file, audio_data is set to NULL, memo is cleared, ref_wav_path is reset, and the status changes to "未生成"

#### Scenario: Reset an unedited segment
- **WHEN** the user clicks the reset button on a segment that has not been edited
- **THEN** the segment's DB record is deleted (if it existed) and the segment shows original text with "未生成" status

### Requirement: Play all segments
The system SHALL provide a "全再生" button in the dialog toolbar that plays all segments in order as a preview. Only segments with generated audio SHALL be played. Segments without audio SHALL be skipped.

#### Scenario: Play all with all segments generated
- **WHEN** the user clicks "全再生" and all segments have generated audio
- **THEN** all segments play in order from segment 0 to the last segment

#### Scenario: Play all with some segments ungenerated
- **WHEN** the user clicks "全再生" and segments 0, 2, 3 have audio but segment 1 does not
- **THEN** segments 0, 2, 3 are played in order, segment 1 is skipped

### Requirement: Generate all ungenerated segments
The system SHALL provide a "全生成" button in the dialog toolbar that generates audio for all segments that currently have no audio_data. Generation SHALL proceed sequentially from the first ungenerated segment. The TTS model SHALL be loaded if not already loaded. Before generating each segment, the system SHALL notify the UI of the segment index being processed so that the per-segment progress indicator can be updated. For each segment, the system SHALL resolve the segment's ref_wav_path to a full filesystem path before passing it to the TTS engine. The resolution SHALL use the same voice file path resolution mechanism used by single-segment regeneration (resolving filename-only values to absolute paths via the voices directory).

#### Scenario: Generate all ungenerated segments
- **WHEN** the user clicks "全生成" with segments 1 and 4 having no audio
- **THEN** segments 1 and 4 are generated in index order using their current text and ref_wav_path, and their status changes to "生成済み"

#### Scenario: Generate all when all segments already generated
- **WHEN** the user clicks "全生成" and all segments have audio
- **THEN** no generation occurs (nothing to generate)

#### Scenario: Per-segment notification during bulk generation
- **WHEN** bulk generation starts processing segment 4
- **THEN** the system notifies the UI with segmentIndex=4 before synthesis begins, enabling the per-segment progress indicator to update

#### Scenario: Generate all resolves per-segment reference audio paths
- **WHEN** the user clicks "全生成" and segment 2 has ref_wav_path="custom_voice.wav"
- **THEN** the system resolves "custom_voice.wav" to the full path (e.g., "/path/to/voices/custom_voice.wav") before passing it to the TTS engine, and the segment generates successfully

#### Scenario: Generate all uses global reference audio for segments without per-segment setting
- **WHEN** the user clicks "全生成" and segment 3 has ref_wav_path=null (no per-segment setting) and the global reference audio is "default_voice.wav"
- **THEN** segment 3 uses the resolved global reference audio path for generation

#### Scenario: Generate all with "なし" reference audio
- **WHEN** the user clicks "全生成" and segment 5 has ref_wav_path="" (explicitly set to "なし")
- **THEN** segment 5 is generated without any reference audio

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

### Requirement: Clear all segments
The system SHALL provide a "全消去" button in the dialog toolbar that deletes all generated audio and resets all segment texts to the originals from `TextSegmenter`. This operation SHALL delete all `tts_segments` records for the episode and update the in-memory segment list to show original texts with "未生成" status. Memo and ref_wav_path SHALL also be cleared.

#### Scenario: Clear all segments
- **WHEN** the user clicks "全消去" for an episode with edited and generated segments
- **THEN** all `tts_segments` records for the episode are deleted, and the list shows all segments with original text and "未生成" status

### Requirement: Dialog cleanup on close
The system SHALL dispose of the TTS Isolate (if loaded) when the edit dialog is closed.

#### Scenario: Close dialog with model loaded
- **WHEN** the user closes the edit dialog after having performed regeneration operations
- **THEN** the TTS Isolate is disposed and memory is freed

### Requirement: Text hash storage on episode creation
The system SHALL compute and store a SHA-256 hash of the episode text in the `tts_episodes.text_hash` column when creating an episode from the edit screen. The hash SHALL be computed from the same text input passed to `loadSegments()` using `sha256.convert(utf8.encode(text))`, identical to the method used by `TtsStreamingController`. When `loadSegments()` finds an existing episode with `text_hash = NULL`, the system SHALL update the episode's `text_hash` to the computed value.

#### Scenario: New episode created with text_hash
- **WHEN** the edit screen creates a new episode (via any segment operation that triggers episode creation) for text content "今日は天気です。明日も晴れるでしょう。"
- **THEN** the episode's `text_hash` column contains the SHA-256 hash of "今日は天気です。明日も晴れるでしょう。"

#### Scenario: Existing episode without text_hash is updated
- **WHEN** `loadSegments()` finds an existing episode for the current file with `text_hash = NULL`
- **THEN** the system computes the SHA-256 hash of the text and updates the episode's `text_hash` column

#### Scenario: Existing episode with valid text_hash is preserved
- **WHEN** `loadSegments()` finds an existing episode with a non-null `text_hash`
- **THEN** the existing `text_hash` value is preserved unchanged

#### Scenario: Hash matches streaming controller computation
- **WHEN** the edit screen creates an episode for text "テスト文章。" and the viewer screen later calls `TtsStreamingController.start()` with the same text
- **THEN** the text hashes match and the streaming controller reuses the existing episode and its segments without deletion
