## ADDED Requirements

### Requirement: Skipped segments are neither played nor generated

During the streaming playback loop, the system SHALL treat a segment whose stored record has `skip = 1` as absent: it SHALL NOT be synthesized, SHALL NOT be played, and SHALL NOT update the text highlight range. The loop SHALL proceed to the next segment.

This check SHALL be independent of `audio_data`. A skipped segment MAY retain stored audio (marking a segment as skipped does not delete it), so the presence of `audio_data` SHALL NOT cause it to be played.

Skipped segments SHALL NOT be counted in the number of segments remaining to generate, so the generation progress indicator reflects only the work that will actually be performed.

#### Scenario: Skipped segment without audio is not generated
- **WHEN** playback reaches a segment whose record has `skip = 1` and `audio_data = NULL`
- **THEN** no synthesis is requested and playback moves to the next segment

#### Scenario: Skipped segment holding audio is not played
- **WHEN** playback reaches a segment whose record has `skip = 1` and non-NULL `audio_data`
- **THEN** the stored audio is not played and playback moves to the next segment

#### Scenario: Skipped segments are excluded from the generation total
- **WHEN** `start()` is called for an episode with 15 segments where 3 have `skip = 1` and no audio, and the remaining 12 have no audio
- **THEN** the reported generation total is 12

#### Scenario: Skipping does not disturb the highlight of neighbouring segments
- **WHEN** segment 4 is skipped and playback moves from segment 3 to segment 5
- **THEN** the highlight range moves directly from segment 3's range to segment 5's range without an intermediate update for segment 4

### Requirement: Blank synthesis input is recorded as skipped instead of synthesized

Before requesting synthesis for a segment, the system SHALL check whether the text to be synthesized is blank (empty after trimming whitespace). When it is blank, the system SHALL NOT call the TTS engine. Instead it SHALL persist a segment record with `skip = 1`, `audio_data = NULL`, and `sample_count = NULL`, then continue with the next segment. This SHALL NOT be reported as a synthesis failure and SHALL NOT stop playback.

Reason: a line consisting only of symbols (e.g. `――‐`) becomes its own segment. Once a no-reading dictionary entry is applied its text becomes empty, and passing an empty string to the engine fails. Because a synthesis failure aborts the run, a single such line would otherwise stop generation and playback for the rest of the episode.

#### Scenario: A dictionary-emptied segment is skipped during streaming
- **WHEN** `start()` reaches a segment with no stored record whose text becomes empty after dictionary substitution
- **THEN** the TTS engine is not called, a record with `skip = 1` and NULL audio is inserted, and playback continues with the next segment

#### Scenario: Blank input does not surface a failure notification
- **WHEN** a segment's synthesis input is blank
- **THEN** no synthesis failure notification is shown and the playback result is not marked as failed

#### Scenario: A whitespace-only stored text is skipped
- **WHEN** playback reaches a segment whose stored text consists only of whitespace and which has no audio
- **THEN** the engine is not called and the segment is recorded as skipped

### Requirement: Episode completion counts skipped segments as satisfied

When the streaming controller updates the episode status after a run, it SHALL treat a segment as satisfied if it holds audio **or** is marked as skipped. The episode SHALL be marked `completed` when the number of satisfied segments reaches the number of segments produced by segmenting the episode text.

Reason: skipped segments never acquire audio by design. Counting only segments with `audio_data` would leave any episode containing a skip permanently `partial`, and the file browser's completion indicator would never appear for it.

#### Scenario: Episode with skipped segments reaches completed
- **WHEN** a run finishes for a 15-segment episode where 12 segments hold audio and 3 are marked as skipped
- **THEN** the episode status is set to `completed`

#### Scenario: Episode with a remaining ungenerated segment stays partial
- **WHEN** a run is stopped for a 15-segment episode where 11 segments hold audio, 3 are skipped, and 1 is neither
- **THEN** the episode status is set to `partial`

### Requirement: A failed run keeps the episode only when real audio exists

When a run ends in failure, the system SHALL decide between preserving the episode as `partial` and deleting it by counting segments that hold audio — skipped segments SHALL NOT count towards that decision, even though they count as satisfied for completion.

Reason: an episode whose only rows are skipped holds nothing playable or exportable. Preserving it would show a "partially generated" indicator for a file with no audio in it — the very state the delete branch exists to prevent.

#### Scenario: A failure leaving only skipped rows deletes the episode
- **WHEN** a run records a blank segment as skipped, then fails synthesizing the next segment, leaving no segment with audio
- **THEN** the episode is deleted and the file reverts to having no TTS audio

#### Scenario: A failure with some real audio preserves the episode
- **WHEN** a run generates audio for one segment, records another as skipped, then fails
- **THEN** the episode is preserved with status `partial`
