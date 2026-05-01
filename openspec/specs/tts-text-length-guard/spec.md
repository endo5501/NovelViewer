## Purpose

Guard rails against runaway TTS synthesis on long text: TextSegmenter splits sentences exceeding 200 chars at the nearest preceding comma (or force-splits at 200), and the synthesis layer derives `max_audio_tokens` dynamically as `min(chars * 15 + 50, 2048)`.

## Requirements

### Requirement: Text length-based sentence splitting
TextSegmenter SHALL split sentences that exceed 200 characters at the nearest comma (「、」) before the threshold. When no comma exists within the first 200 characters, the system SHALL force-split at 200 characters. The 200-character check SHALL be applied to the spoken text (after ruby tag processing), not the raw HTML text. The existing sentence-ending rules (「。」「！」「？」「\n」) SHALL continue to take priority over length-based splitting.

#### Scenario: Sentence under 200 characters is not split
- **WHEN** TextSegmenter processes a sentence of 150 characters with no sentence-ending punctuation
- **THEN** the sentence is returned as a single segment

#### Scenario: Sentence over 200 characters is split at comma
- **WHEN** TextSegmenter processes a 250-character sentence containing a comma at position 180
- **THEN** the sentence is split into two segments: characters 0-180 and 181-249

#### Scenario: Sentence over 200 characters with no comma is force-split
- **WHEN** TextSegmenter processes a 300-character sentence with no commas
- **THEN** the sentence is split at the 200-character boundary

#### Scenario: Multiple commas in long sentence splits at nearest to threshold
- **WHEN** TextSegmenter processes a 400-character sentence with commas at positions 80, 160, and 280
- **THEN** the first split occurs at position 160 (the last comma within 200 characters), and the remaining 240 characters are evaluated again for splitting

#### Scenario: Sentence-ending punctuation still takes priority
- **WHEN** TextSegmenter processes a 250-character text containing「。」at position 120
- **THEN** the text is split at position 120 by the existing sentence-ending rule, and neither resulting segment exceeds 200 characters

#### Scenario: Recursive splitting for very long sentences
- **WHEN** TextSegmenter processes a 500-character sentence with commas at positions 150, 320, and 450
- **THEN** the sentence is split into three segments: 0-150, 151-320, 321-499

### Requirement: Dynamic max_audio_tokens calculation
The Dart TtsEngine (or the layer calling the C API) SHALL calculate max_audio_tokens for each synthesis call using the formula: `min(text_length_in_characters * 15 + 50, 2048)`, where `text_length_in_characters` is the number of characters in the input text. The calculated value SHALL be passed to the C API synthesize function.

#### Scenario: Short text gets proportional limit
- **WHEN** a 10-character text is synthesized
- **THEN** max_audio_tokens is set to min(10 * 15 + 50, 2048) = 200

#### Scenario: Medium text gets proportional limit
- **WHEN** a 50-character text is synthesized
- **THEN** max_audio_tokens is set to min(50 * 15 + 50, 2048) = 800

#### Scenario: Long text is capped at 2048
- **WHEN** a 200-character text is synthesized
- **THEN** max_audio_tokens is set to min(200 * 15 + 50, 2048) = 2048

#### Scenario: Very short text has minimum floor
- **WHEN** a 1-character text is synthesized
- **THEN** max_audio_tokens is set to min(1 * 15 + 50, 2048) = 65
