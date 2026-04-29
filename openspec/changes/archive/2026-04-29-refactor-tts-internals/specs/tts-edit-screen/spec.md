## MODIFIED Requirements

### Requirement: Segment list display
The system SHALL display all segments of the current episode as a scrollable list in the TTS edit dialog. Segments SHALL be obtained by running the shared `TextSegmenter` instance (provided via `textSegmenterProvider`) on the original episode text file, then merging with existing `tts_segments` records by `segment_index`. For segments with existing DB records, the DB values (text, ref_wav_path, memo) SHALL be displayed. For segments without DB records, the original text from `TextSegmenter` SHALL be displayed.

#### Scenario: Display segments for episode with no prior edits
- **WHEN** the edit dialog opens for an episode with no existing `tts_segments` records
- **THEN** all segments show the original text from the shared `TextSegmenter` (read via `textSegmenterProvider`), status "未生成", and default reference audio

#### Scenario: Display segments for episode with existing audio
- **WHEN** the edit dialog opens for an episode with some segments already generated
- **THEN** segments with `audio_data` show status "生成済み" and their stored text, segments without records show original text and status "未生成"

#### Scenario: Display segments for episode with edited but ungenerated segments
- **WHEN** the edit dialog opens for an episode where the user previously edited text but did not regenerate
- **THEN** the edited text from DB is displayed and status shows "未生成"

#### Scenario: TextSegmenter is shared across the app
- **WHEN** any TTS controller or dialog uses `TextSegmenter`
- **THEN** the instance is obtained via `ref.read(textSegmenterProvider)` rather than constructed locally, so all consumers receive the same instance

### Requirement: Segment preview playback
The system SHALL allow playing a single segment's audio via the play button on each row. The play button SHALL only be enabled when the segment has generated audio (audio_data is not NULL). Per-segment playback SHALL be delegated to the shared `SegmentPlayer`. After playback completes, the `SegmentPlayer` SHALL call `pause()` on the audio player to reset the internal `playing` flag. The system SHALL NOT call `stop()` after segment playback, as `stop()` destroys the underlying platform player and kills any remaining audio in the output buffer.

#### Scenario: Play a generated segment
- **WHEN** the user clicks the play button for a segment with audio_data
- **THEN** the edit controller writes the WAV BLOB to a temporary file and asks the `SegmentPlayer` to play it; on completion the `SegmentPlayer` calls `pause()` (not `stop()`) on the underlying audio player

#### Scenario: Play button disabled when no audio
- **WHEN** a segment has audio_data=NULL
- **THEN** the play button is disabled or hidden
