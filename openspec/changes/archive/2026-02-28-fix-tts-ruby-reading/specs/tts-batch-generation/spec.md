## ADDED Requirements

### Requirement: Ruby text used for batch TTS synthesis
The system SHALL use ruby text (furigana from `<rt>` elements) instead of base text when preparing text segments for batch TTS audio generation. When splitting episode text into sentences, the text segmenter SHALL replace each `<ruby>` block with the content of its `<rt>` element, ensuring the TTS engine synthesizes audio using the author-intended pronunciation.

#### Scenario: Batch generation uses ruby text for synthesis
- **WHEN** batch generation processes the text `<ruby>魔法杖職人<rt>ワンドメーカー</rt></ruby>は言った。`
- **THEN** the TTS engine receives "ワンドメーカーは言った。" as the sentence to synthesize

#### Scenario: Segment text in database reflects ruby reading
- **WHEN** a segment is generated from text containing `<ruby>異世界<rt>いせかい</rt></ruby>へ。`
- **THEN** the segment stored in the `tts_segments` table has text "いせかいへ。"

#### Scenario: Edit screen displays ruby reading text
- **WHEN** the TTS edit screen shows segments generated from ruby-containing text
- **THEN** each segment displays the ruby text (furigana) rather than the base text (kanji)
