## MODIFIED Requirements

### Requirement: Playback start position
The system SHALL determine the playback start position from the current text selection. The selection SHALL be tracked as both the selected text and the selection's start offset expressed in **plain-text coordinates** — the coordinate space of the text after ruby markup has been replaced by its base text, which is the same space used by `TtsSegment.offset`, `tts_segments.text_offset`, and the TTS highlight range. The system SHALL NOT reconstruct the offset by searching the selected text within the raw file content.

When a selection offset is available, playback SHALL begin from the segment with the largest `offset` <= the selection offset, resolved against the segment list produced by segmenting the current text. Segments that have no stored audio SHALL be eligible as the start position; the resolution SHALL NOT be restricted to segments already present in the database. If no segment satisfies the condition, or if no text is selected, playback SHALL begin from segment 0.

#### Scenario: Start from selected text position
- **WHEN** the user has selected text whose plain-text start offset is 50 and presses play
- **THEN** playback begins from the segment whose offset is the largest value <= 50

#### Scenario: Start position is unaffected by ruby markup
- **WHEN** the text contains ruby markup such as `<ruby>魔法<rp>《</rp><rt>まほう</rt><rp>》</rp></ruby>` before the selected position, and the user selects a sentence and presses play
- **THEN** playback begins from the selected sentence, not from a later sentence shifted by the length of the ruby markup

#### Scenario: Start from a selection that contains ruby
- **WHEN** the user selects a range that includes a ruby-annotated word and presses play
- **THEN** playback begins from the segment containing the start of that selection, not from segment 0

#### Scenario: Start from a segment that has not been generated
- **WHEN** the episode is in "partial" status with only segments 0-9 stored in the database, and the user selects a position inside segment 60 and presses play
- **THEN** playback begins from segment 60, generating its audio on demand, rather than from segment 9

#### Scenario: Start from beginning when no selection
- **WHEN** no text is selected and the user presses play
- **THEN** playback begins from segment 0

#### Scenario: Repeated text does not misresolve the start position
- **WHEN** the user selects an occurrence of a short string that also appears earlier in the same episode and presses play
- **THEN** playback begins from the segment containing the selected occurrence, not from the segment containing the first occurrence in the text
