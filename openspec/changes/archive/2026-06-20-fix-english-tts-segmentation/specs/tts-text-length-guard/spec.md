## MODIFIED Requirements

### Requirement: Text length-based sentence splitting
TextSegmenter SHALL split sentences that exceed 200 characters at the nearest comma before the threshold, where a comma is either the full-width comma (`、`) or the half-width comma (`,`). When no comma exists within the first 200 characters, the system SHALL split at the nearest whitespace (word boundary) within the first 200 characters so that splitting does not occur in the middle of a word. When neither a comma nor a whitespace character exists within the first 200 characters, the system SHALL force-split at 200 characters. The 200-character check SHALL be applied to the spoken text (after ruby tag processing), not the raw HTML text. The existing sentence-ending rules (`。`, `！`, `？`, `.`, `!`, `?`, `\n`) SHALL continue to take priority over length-based splitting.

#### Scenario: Sentence under 200 characters is not split
- **WHEN** TextSegmenter processes a sentence of 150 characters with no sentence-ending punctuation
- **THEN** the sentence is returned as a single segment

#### Scenario: Sentence over 200 characters is split at comma
- **WHEN** TextSegmenter processes a 250-character sentence containing a comma at position 180
- **THEN** the sentence is split into two segments: characters 0-180 and 181-249

#### Scenario: Sentence over 200 characters with no comma is force-split
- **WHEN** TextSegmenter processes a 300-character sentence with no commas and no whitespace
- **THEN** the sentence is split at the 200-character boundary

#### Scenario: Multiple commas in long sentence splits at nearest to threshold
- **WHEN** TextSegmenter processes a 400-character sentence with commas at positions 80, 160, and 280
- **THEN** the first split occurs at position 160 (the last comma within 200 characters), and the remaining 240 characters are evaluated again for splitting

#### Scenario: Sentence-ending punctuation still takes priority
- **WHEN** TextSegmenter processes a 250-character text containing `。` at position 120
- **THEN** the text is split at position 120 by the existing sentence-ending rule, and neither resulting segment exceeds 200 characters

#### Scenario: Recursive splitting for very long sentences
- **WHEN** TextSegmenter processes a 500-character sentence with commas at positions 150, 320, and 450
- **THEN** the sentence is split into three segments: 0-150, 151-320, 321-499

#### Scenario: Long English sentence is split at a half-width comma
- **WHEN** TextSegmenter processes a long English sentence (over 200 characters) that contains half-width commas (`,`)
- **THEN** the sentence is split at the last half-width comma within the first 200 characters, and the comma is included at the end of the first segment

#### Scenario: Long sentence without a comma is split at a word boundary
- **WHEN** TextSegmenter processes a long English sentence (over 200 characters) that has no comma but contains spaces between words
- **THEN** the sentence is split at the last whitespace within the first 200 characters, and no segment ends in the middle of a word
