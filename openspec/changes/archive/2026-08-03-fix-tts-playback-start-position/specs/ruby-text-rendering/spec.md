## ADDED Requirements

### Requirement: Widget-display offset to plain-text offset conversion
The system SHALL provide a conversion from a `SelectableText.rich` display offset — the coordinate space in which each `WidgetSpan` (one ruby annotation) counts as a single character — to a plain-text offset, the coordinate space produced by concatenating `PlainTextSegment.text` and `RubyTextSegment.base`. The conversion SHALL walk the parsed segment list, advancing by `text.length` for a plain segment and by `base.length` for a ruby segment, and SHALL return the accumulated plain-text length at the given display offset. A display offset that falls inside a plain segment SHALL contribute the corresponding partial length; a display offset that falls on a ruby segment SHALL resolve to the plain-text position of that segment's base start. Offsets beyond the end of the segments SHALL clamp to the total plain-text length.

#### Scenario: Offset in plain text before any ruby
- **WHEN** the segments are `["これは", ruby(漢字/かんじ), "です"]` and the display offset is 2
- **THEN** the plain-text offset is 2

#### Scenario: Offset after a ruby segment
- **WHEN** the segments are `["これは", ruby(漢字/かんじ), "です"]` and the display offset is 4 (the character `で`, since the ruby counts as one display character at index 3)
- **THEN** the plain-text offset is 5, matching the position of `で` in "これは漢字です"

#### Scenario: Offset on a ruby segment resolves to its base start
- **WHEN** the segments are `["これは", ruby(漢字/かんじ), "です"]` and the display offset is 3 (the ruby segment itself)
- **THEN** the plain-text offset is 3, the position of `漢` in "これは漢字です"

#### Scenario: Offset beyond the end clamps
- **WHEN** the display offset exceeds the total display length of the segments
- **THEN** the returned plain-text offset equals the total plain-text length

#### Scenario: Conversion agrees with plain text extraction
- **WHEN** the plain-text offset for display offset `n` is computed for any segment list
- **THEN** it equals the length of the plain text extracted from display offset 0 to `n`
