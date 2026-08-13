## MODIFIED Requirements

### Requirement: Kinsoku processing for column splitting
The system SHALL apply Japanese line-breaking rules (禁則処理) when splitting text into vertical columns. Line-head forbidden characters (行頭禁則文字) SHALL NOT appear as the first character of a column. Line-end forbidden characters (行末禁則文字) SHALL NOT appear as the last character of a column. The system SHALL use the "push-out" (追い出し) method to resolve violations: when a line-head forbidden character would appear at the start of a new column, the last character of the current column SHALL be moved to the start of the next column (making the current column one character shorter), so the forbidden character becomes the second character of the next column rather than the first. When a line-end forbidden character appears at the end of a column, it SHALL be moved to the start of the next column. All columns SHALL have at most `charsPerColumn` characters to ensure compatibility with the Wrap widget's vertical height constraint. Kinsoku character sets and判定 functions SHALL be defined in a separate data-layer module (`kinsoku.dart`) alongside other character-processing utilities.

Line-head forbidden characters (行頭禁則文字):
- Punctuation: `。、，．,.`
- Closing brackets: `）」』】〕｝〉》﹂﹄︶﹈︸﹀︼︺︘︾)]}`
- Middle dots and colons: `・：；`
- Exclamation and question marks: `！？!?`
- Long vowel mark: `ー`
- Leaders: `…‥`
- Small kana: `ぁぃぅぇぉっゃゅょゎァィゥェォッャュョヮヵヶ`

Line-end forbidden characters (行末禁則文字):
- Opening brackets: `（「『【〔｛〈《﹁﹃︵﹇︷︿︻︹︗︽([{`

RubyTextSegment SHALL be treated as an indivisible unit during kinsoku processing. The first base character of a RubyTextSegment SHALL be used for line-head forbidden character check, and the last base character SHALL be used for line-end forbidden character check.

A RubyTextSegment whose base text is empty SHALL be accepted without raising an exception. Such a segment SHALL contribute a character count of 0 to its column, and SHALL have no character available for the line-head or line-end forbidden character checks, so neither check SHALL be satisfied by it. Column splitting SHALL proceed as if the segment occupied no column space, while the segment itself SHALL still be emitted into the column so its ruby annotation remains visible.

Because such a segment carries no character, it SHALL NOT hide a neighbouring character from the forbidden character checks. The line-head check at a column boundary SHALL use the first character of the first entry at or after the boundary that has a character, and the line-end check SHALL use the last character of the last entry in the column that has a character. Consequently the column structure of a line containing empty-base ruby segments SHALL have the same character-per-column layout as the same line with those segments removed.

#### Scenario: Line-head forbidden character triggers push-out of last column character
- **WHEN** a column split would place a line-head forbidden character (e.g., `。`, `、`, `）`, `」`) as the first character of a new column
- **THEN** the system SHALL move the last character of the current column to the start of the next column, making the current column one character shorter than `charsPerColumn`, so the forbidden character becomes the second character of the next column

#### Scenario: Line-end forbidden character is pushed to next column
- **WHEN** a column is filled to `charsPerColumn` and the last character is a line-end forbidden character (e.g., `（`, `「`, `『`)
- **THEN** the system SHALL move that character to the start of the next column, making the current column one character shorter than `charsPerColumn`

#### Scenario: Consecutive line-head forbidden characters are handled by push-out
- **WHEN** a column split would place multiple consecutive line-head forbidden characters (e.g., `。」` or `！？」`) at the start of a new column
- **THEN** the system SHALL push the last character of the current column to the next column, and the consecutive forbidden characters SHALL naturally follow as non-first characters in the next column

#### Scenario: No kinsoku violation at column boundary
- **WHEN** a column split occurs and neither the next character is line-head forbidden nor the last character is line-end forbidden
- **THEN** the column split SHALL occur at the standard `charsPerColumn` boundary without adjustment

#### Scenario: Kinsoku with RubyTextSegment
- **WHEN** a RubyTextSegment would begin a new column and the first base character of that segment is a line-head forbidden character
- **THEN** the last character of the current column SHALL be moved to the start of the next column, so the RubyTextSegment becomes the second entry of the next column

#### Scenario: First column is not affected by kinsoku
- **WHEN** the first character of the first column in a line is a line-head forbidden character
- **THEN** no adjustment SHALL be made because there is no previous column to push the character into

#### Scenario: Column at end of line is not affected by line-end kinsoku
- **WHEN** the last column of a line ends with a line-end forbidden character and no more text follows in the line
- **THEN** no adjustment SHALL be made because no subsequent column exists within the same line

#### Scenario: RubyTextSegment with empty base text does not raise
- **WHEN** a line containing a RubyTextSegment whose base text is empty (e.g. parsed from `<ruby><rb></rb><rp>(</rp><rt>戦術的優位性</rt><rp>)</rp></ruby>`) is split into columns
- **THEN** column splitting SHALL complete without raising an exception, and the empty-base segment SHALL be present in the resulting columns

#### Scenario: Empty-base RubyTextSegment consumes no column space
- **WHEN** a line contains exactly `charsPerColumn` plain characters plus one RubyTextSegment with empty base text
- **THEN** the resulting columns SHALL be split as if only the plain characters were present, because the empty-base segment contributes a character count of 0

#### Scenario: Empty-base RubyTextSegment at a column boundary is not subject to kinsoku
- **WHEN** an empty-base RubyTextSegment sits at a column boundary, either as the entry that would start the next column or as the last entry of the current column
- **THEN** neither the line-head nor the line-end forbidden character check SHALL be satisfied by that segment, and no push-out adjustment SHALL be triggered by it

#### Scenario: Empty-base RubyTextSegment does not hide a following line-head forbidden character
- **WHEN** one or more empty-base RubyTextSegments sit at a column boundary immediately before a line-head forbidden character
- **THEN** the line-head check SHALL read past those segments to that forbidden character, and the push-out SHALL be applied, so the forbidden character does not become the first character a reader sees in the new column

#### Scenario: Empty-base RubyTextSegments do not change the character layout of a line
- **WHEN** a line containing empty-base RubyTextSegments is split into columns
- **THEN** the characters in each column SHALL be identical to the columns produced from the same line with those segments removed
