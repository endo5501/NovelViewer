## MODIFIED Requirements

### Requirement: Text segmentation for TTS
The system SHALL split novel text into sentence-level segments for TTS processing. Segmentation SHALL occur at full-width sentence-ending punctuation (`。`, `！`, `？`), at half-width sentence-ending punctuation (`.`, `!`, `?`), and at newline characters. A half-width sentence-ending punctuation mark SHALL be treated as a sentence boundary only when, after skipping any run of immediately-following closing brackets, the next character is a whitespace character or the end of the text; otherwise it SHALL NOT trigger a split (so decimals such as `3.14`, mid-word periods, and an opening quote that directly follows a period such as `A."Bcd` are preserved). When a closing bracket (`」`, `』`, `）`, `"`, `)`) immediately follows sentence-ending punctuation, the split SHALL occur after the closing bracket. Empty segments SHALL be excluded. Ruby HTML tags SHALL be stripped to plain text (base text only) before segmentation. The Ruby tag stripping pattern SHALL handle all common Ruby HTML formats including those with `<rb>` tags and optional `<rp>` tags, and SHALL use the same regex pattern as `parseRubyText` to ensure consistent offset calculation. Each segment SHALL track its start offset and length relative to the stripped text. When a segment is created by splitting at a newline, the offset SHALL account for any leading whitespace that is trimmed: the offset SHALL point to the first non-whitespace character, and the length SHALL equal the trimmed text length.

#### Scenario: Split text at sentence-ending punctuation
- **WHEN** text "今日は天気です。明日も晴れるでしょう。" is segmented
- **THEN** two segments are produced: "今日は天気です。" (offset 0, length 8) and "明日も晴れるでしょう。" (offset 8, length 11)

#### Scenario: Split at closing bracket after punctuation
- **WHEN** text "「走れ！」彼は叫んだ。" is segmented
- **THEN** two segments are produced: "「走れ！」" and "彼は叫んだ。"

#### Scenario: Split at newlines
- **WHEN** text "第一章\n物語の始まり。" is segmented
- **THEN** two segments are produced: "第一章" and "物語の始まり。"

#### Scenario: Skip empty segments
- **WHEN** text contains consecutive newlines like "前文。\n\n後文。"
- **THEN** empty segments between newlines are excluded, producing "前文。" and "後文。"

#### Scenario: Strip ruby tags before segmentation
- **WHEN** text contains ruby tags like "<ruby>漢字<rp>(</rp><rt>かんじ</rt><rp>)</rp></ruby>を読む。"
- **THEN** segmentation operates on plain text "漢字を読む。" and produces one segment

#### Scenario: Strip ruby tags with rb element
- **WHEN** text contains ruby tags with rb element like "<ruby><rb>漢字</rb><rt>かんじ</rt></ruby>を読む。"
- **THEN** segmentation operates on plain text "漢字を読む。" and produces one segment with the same offset as the parseRubyText-based display

#### Scenario: Ruby tag pattern matches parseRubyText pattern
- **WHEN** text contains any Ruby HTML tag format
- **THEN** the TextSegmenter's ruby stripping SHALL produce the same plain text as concatenating all PlainTextSegment.text and RubyTextSegment.base from parseRubyText output

#### Scenario: Trim adjusts offset for leading whitespace at newline split
- **WHEN** text "テスト。\n　第二章\n次の行。" is segmented and "　第二章" is split at a newline
- **THEN** the segment text is "第二章" with offset pointing to the position of "第" (after the full-width space), not the position of "　"

#### Scenario: Split English text at half-width period followed by space
- **WHEN** text "Hello world. Goodbye world." is segmented
- **THEN** two segments are produced: "Hello world." and "Goodbye world."

#### Scenario: Split English text at question mark and exclamation mark
- **WHEN** text "Who are you? Run away! Now." is segmented
- **THEN** three segments are produced: "Who are you?", "Run away!", and "Now."

#### Scenario: Do not split at a decimal point
- **WHEN** text "The value is 3.14 today." is segmented
- **THEN** one segment is produced: "The value is 3.14 today." (the period in `3.14` is not a boundary because it is followed by a digit)

#### Scenario: Split dialogue at a period before a closing quote
- **WHEN** text "He said \"OK.\" She replied." is segmented
- **THEN** two segments are produced: "He said \"OK.\"" and "She replied." (the closing quote after the period is absorbed into the first segment)

#### Scenario: Do not split when a closing bracket is followed by a word
- **WHEN** text "A.\"Bcd and more text follows here." is segmented
- **THEN** one segment is produced, because after skipping the closing quote the next character is a letter (not whitespace), so the period is not treated as a boundary and the opening quote is not absorbed into a previous sentence
