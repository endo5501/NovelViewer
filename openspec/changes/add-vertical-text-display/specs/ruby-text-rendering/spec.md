## MODIFIED Requirements

### Requirement: Ruby text visual rendering
The system SHALL render ruby-annotated text with the ruby annotation (furigana) positioned according to the current display mode. In horizontal mode, the ruby annotation SHALL be displayed above the base text. In vertical mode, the ruby annotation SHALL be displayed to the right of the base text. In both modes, the ruby text SHALL use a smaller font size.

#### Scenario: Ruby annotation displayed above base text in horizontal mode
- **WHEN** a ruby segment with base "漢字" and ruby "かんじ" is rendered in horizontal mode
- **THEN** "かんじ" is displayed above "漢字" with a smaller font size

#### Scenario: Ruby annotation displayed to the right of base text in vertical mode
- **WHEN** a ruby segment with base "漢字" and ruby "かんじ" is rendered in vertical mode
- **THEN** "かんじ" is displayed to the right of "漢字" with a smaller font size

#### Scenario: Ruby text rendered inline with surrounding text in horizontal mode
- **WHEN** ruby segments appear between plain text segments in horizontal mode
- **THEN** the ruby-annotated text flows inline with the surrounding plain text without breaking the line flow

#### Scenario: Ruby text rendered inline with surrounding characters in vertical mode
- **WHEN** ruby segments appear between plain text segments in vertical mode
- **THEN** the ruby-annotated text flows inline with the surrounding characters in the vertical column

#### Scenario: Plain text segments rendered normally
- **WHEN** a plain text segment is rendered
- **THEN** it is displayed with the standard text style, identical to the current rendering behavior

### Requirement: Search highlight with ruby text
The system SHALL support search query highlighting on ruby-aware content in both horizontal and vertical display modes, highlighting matches in the base text of ruby segments and in plain text segments.

#### Scenario: Highlight match in ruby base text in horizontal mode
- **WHEN** the search query is "漢字" and a ruby segment has base text "漢字" in horizontal mode
- **THEN** the base text "漢字" in the ruby segment is highlighted with a distinct background color

#### Scenario: Highlight match in ruby base text in vertical mode
- **WHEN** the search query is "漢字" and a ruby segment has base text "漢字" in vertical mode
- **THEN** the base text "漢字" in the ruby segment is highlighted with a distinct background color

#### Scenario: Highlight match in plain text segment
- **WHEN** the search query is "冒険" and a plain text segment contains "冒険"
- **THEN** the matching text is highlighted with a distinct background color in both display modes
