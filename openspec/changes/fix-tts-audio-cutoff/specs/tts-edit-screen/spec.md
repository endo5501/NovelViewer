## MODIFIED Requirements

### Requirement: Segment preview playback
The system SHALL allow playing a single segment's audio via the play button on each row. The play button SHALL only be enabled when the segment has generated audio (audio_data is not NULL). After playback completes, the system SHALL call `pause()` on the audio player to reset the internal `playing` flag. The system SHALL NOT call `stop()` after segment playback, as `stop()` destroys the underlying platform player and kills any remaining audio in the output buffer.

#### Scenario: Play a generated segment
- **WHEN** the user clicks the play button on a segment with generated audio
- **THEN** the segment's audio plays as a preview within the edit dialog

#### Scenario: Play button disabled for ungenerated segment
- **WHEN** a segment has no generated audio (audio_data is NULL)
- **THEN** the play button is disabled

#### Scenario: pause() called after segment playback completes
- **WHEN** a segment finishes playing in the edit dialog
- **THEN** the system calls `pause()` on the audio player, resetting the `playing` flag so that the next `play()` call functions correctly

#### Scenario: stop() not called after segment playback
- **WHEN** a segment finishes playing in the edit dialog
- **THEN** the system SHALL NOT call `stop()` after playback, preserving the underlying platform player

### Requirement: Play all segments
The system SHALL provide a "全再生" button in the dialog toolbar that plays all segments in order as a preview. Only segments with generated audio SHALL be played. Segments without audio SHALL be skipped. Between segments, the system SHALL use `pause()` (not `stop()`) to reset the audio player's `playing` flag, ensuring each subsequent `play()` call functions correctly.

#### Scenario: Play all with all segments generated
- **WHEN** the user clicks "全再生" and all segments have generated audio
- **THEN** all segments play in order from segment 0 to the last segment, with `pause()` called between each segment transition

#### Scenario: Play all with some segments ungenerated
- **WHEN** the user clicks "全再生" and segments 0, 2, 3 have audio but segment 1 does not
- **THEN** segments 0, 2, 3 are played in order, segment 1 is skipped

#### Scenario: Play all transitions cleanly between segments
- **WHEN** segment N completes during "全再生" playback
- **THEN** the system calls `pause()` to reset the `playing` flag, then loads and plays segment N+1 without audio cutoff or skipping
