## ADDED Requirements

### Requirement: Ruby text used for TTS synthesis
The system SHALL use ruby text (furigana from `<rt>` elements) instead of base text when preparing text segments for TTS synthesis. When the text segmenter strips ruby HTML tags, it SHALL replace each `<ruby>` block with the content of its `<rt>` element rather than the base text. This ensures that the TTS engine receives the author-intended pronunciation.

#### Scenario: Ruby text extracted for single ruby tag
- **WHEN** the text contains `<ruby>一軒家<rt>いっけんや</rt></ruby>`
- **THEN** the text segmenter produces "いっけんや" as the text for that portion

#### Scenario: Ruby text extracted for multiple ruby tags
- **WHEN** the text contains `<ruby>魔法<rt>まほう</rt></ruby>の<ruby>杖<rt>つえ</rt></ruby>`
- **THEN** the text segmenter produces "まほうのつえ" as the text for that portion

#### Scenario: Ruby text extracted with rp elements present
- **WHEN** the text contains `<ruby>漢字<rp>(</rp><rt>かんじ</rt><rp>)</rp></ruby>`
- **THEN** the text segmenter produces "かんじ" as the text for that portion

#### Scenario: Ruby text extracted with rb elements present
- **WHEN** the text contains `<ruby><rb>八百万</rb><rp>（</rp><rt>やおよろず</rt><rp>）</rp></ruby>`
- **THEN** the text segmenter produces "やおよろず" as the text for that portion

#### Scenario: Mixed plain and ruby text segmented correctly
- **WHEN** the text contains `これは<ruby>漢字<rt>かんじ</rt></ruby>です。`
- **THEN** the text segmenter produces "これはかんじです。" as the full segment text

#### Scenario: Text hash changes trigger regeneration
- **WHEN** a previously generated episode's text is re-segmented with ruby text extraction
- **THEN** the text hash differs from the stored hash and the existing audio is automatically regenerated
