## ADDED Requirements

### Requirement: Ruby text parsing
The system SHALL parse HTML ruby tags in text content and convert them into structured segments consisting of plain text and ruby-annotated text.

#### Scenario: Parse standard ruby tag
- **WHEN** the text content contains `<ruby>漢字<rp>(</rp><rt>かんじ</rt><rp>)</rp></ruby>`
- **THEN** the parser produces a ruby segment with base text "漢字" and ruby text "かんじ"

#### Scenario: Parse ruby tag without rp elements
- **WHEN** the text content contains `<ruby>漢字<rt>かんじ</rt></ruby>`
- **THEN** the parser produces a ruby segment with base text "漢字" and ruby text "かんじ"

#### Scenario: Parse multiple ruby tags in a line
- **WHEN** the text content contains `<ruby>魔法<rp>(</rp><rt>まほう</rt><rp>)</rp></ruby>の<ruby>杖<rp>(</rp><rt>つえ</rt><rp>)</rp></ruby>`
- **THEN** the parser produces a ruby segment for "魔法"/"まほう", a plain text segment for "の", and a ruby segment for "杖"/"つえ"

#### Scenario: Parse text without ruby tags
- **WHEN** the text content contains no ruby tags (e.g., "普通のテキスト")
- **THEN** the parser produces a single plain text segment with the original text

#### Scenario: Parse mixed content across lines
- **WHEN** the text content contains multiple lines with ruby tags on some lines and plain text on others
- **THEN** the parser correctly produces segments for each line, preserving newline characters in plain text segments

### Requirement: Plain text extraction from segments
The system SHALL provide a plain text representation from parsed segments by concatenating base text from ruby segments and text from plain text segments.

#### Scenario: Extract plain text from mixed segments
- **WHEN** segments contain a mix of plain text and ruby-annotated text
- **THEN** the plain text output contains the base text of ruby segments without ruby annotations or HTML tags

#### Scenario: Plain text matches visible content
- **WHEN** the text `これは<ruby>漢字<rp>(</rp><rt>かんじ</rt><rp>)</rp></ruby>です` is parsed
- **THEN** the plain text output is "これは漢字です"

### Requirement: Ruby text visual rendering
The system SHALL render ruby-annotated text with the ruby annotation (furigana) positioned according to the current display mode. In horizontal mode, the ruby annotation SHALL be displayed above the base text. In vertical mode, the ruby annotation SHALL be displayed to the right of the base text. In both modes, the ruby text SHALL use a smaller font size.

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
