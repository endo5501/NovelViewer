## ADDED Requirements

### Requirement: Empty-base ruby annotation is valid input
The system SHALL treat an HTML ruby element whose base text is empty (e.g. `<ruby><rb></rb><rp>(</rp><rt>ルビ</rt><rp>)</rp></ruby>`) as valid input, because such markup occurs in the source HTML of supported novel sites and is preserved verbatim by the downloader. The parser SHALL produce a ruby segment with an empty base text and the given ruby text. Neither display mode SHALL raise an exception when rendering such a segment, and both SHALL display the ruby annotation with no base characters beneath (horizontal mode) or beside (vertical mode) it. In the plain-text coordinate space — the space shared by plain-text extraction, TTS highlight offsets, selection offsets, and mark matching — an empty-base ruby segment SHALL contribute a length of 0.

#### Scenario: Parse ruby tag with empty base
- **WHEN** the text content contains `<ruby><rb></rb><rp>(</rp><rt>戦術的優位性</rt><rp>)</rp></ruby>`
- **THEN** the parser produces a ruby segment with base text "" and ruby text "戦術的優位性"

#### Scenario: Empty-base ruby contributes nothing to plain text
- **WHEN** the text `何の<ruby><rb></rb><rp>(</rp><rt>ルビ</rt><rp>)</rp></ruby>もなかった` is parsed
- **THEN** the plain text output is "何のもなかった"

#### Scenario: Empty-base ruby renders without error in horizontal mode
- **WHEN** a ruby segment with empty base text and ruby text "ルビ" is rendered in horizontal mode
- **THEN** rendering completes without raising an exception and "ルビ" is displayed with no base characters below it

#### Scenario: Empty-base ruby renders without error in vertical mode
- **WHEN** a ruby segment with empty base text and ruby text "ルビ" is rendered in vertical mode
- **THEN** rendering completes without raising an exception and "ルビ" is displayed with no base characters to its left

#### Scenario: File containing empty-base ruby opens in vertical mode
- **WHEN** a text file containing at least one empty-base ruby annotation is opened in vertical display mode
- **THEN** the page content SHALL be displayed, and the viewer SHALL NOT fall back to the framework error widget
