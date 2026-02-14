## MODIFIED Requirements

### Requirement: Ruby text visual rendering
The system SHALL render ruby-annotated text with the ruby annotation (furigana) positioned according to the current display mode. In horizontal mode, the ruby annotation SHALL be displayed above the base text. In vertical mode, the ruby annotation SHALL be displayed to the right of the base text. In both modes, the ruby text SHALL use a smaller font size. In vertical mode, the ruby text characters SHALL be mapped through the vertical character map (`verticalCharMap`) in the same manner as the base text characters, so that punctuation, brackets, dashes, and other mapped characters in ruby annotations are correctly transformed for vertical display.

#### Scenario: Ruby annotation displayed above base text in horizontal mode
- **WHEN** a ruby segment with base "漢字" and ruby "かんじ" is rendered in horizontal mode
- **THEN** "かんじ" is displayed above "漢字" with a smaller font size

#### Scenario: Ruby annotation displayed to the right of base text in vertical mode
- **WHEN** a ruby segment with base "漢字" and ruby "かんじ" is rendered in vertical mode
- **THEN** "かんじ" is displayed to the right of "漢字" with a smaller font size, using a Stack-based overlay so that the ruby text does not affect the column width in the Wrap layout

#### Scenario: Ruby text rendered inline with surrounding text in horizontal mode
- **WHEN** ruby segments appear between plain text segments in horizontal mode
- **THEN** the ruby-annotated text flows inline with the surrounding plain text without breaking the line flow

#### Scenario: Ruby text rendered inline with surrounding characters in vertical mode
- **WHEN** ruby segments appear between plain text segments in vertical mode
- **THEN** the ruby-annotated text flows inline with the surrounding characters in the vertical column, with the base text aligned to the same column width as plain characters

#### Scenario: Plain text segments rendered normally
- **WHEN** a plain text segment is rendered
- **THEN** it is displayed with the standard text style, identical to the current rendering behavior

#### Scenario: Ruby text characters are mapped for vertical display
- **WHEN** a ruby segment with ruby text containing verticalCharMap-mapped characters (e.g., brackets "（）", dashes "ー", punctuation "。") is rendered in vertical mode
- **THEN** the ruby text characters SHALL be transformed through the vertical character map, producing their vertical equivalents (e.g., "（" → "︵", "ー" → "丨", "。" → "︒")

#### Scenario: Ruby text with unmapped characters remains unchanged in vertical mode
- **WHEN** a ruby segment with ruby text containing only hiragana or katakana (e.g., "かんじ") is rendered in vertical mode
- **THEN** the ruby text characters remain unchanged since they have no vertical character map entries
