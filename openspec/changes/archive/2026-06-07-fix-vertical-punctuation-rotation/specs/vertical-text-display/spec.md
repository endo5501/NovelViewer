## ADDED Requirements

### Requirement: Vertical punctuation rotation

The system SHALL render a defined set of horizontal-specific punctuation characters by physically rotating the glyph 90° clockwise (using `Transform.rotate` with an angle of π/2 radians) when rendering in vertical mode, instead of substituting them with Unicode vertical presentation forms. The rotation SHALL be a paint-only transform that does NOT change the character cell's layout dimensions: the rotated cell SHALL occupy the same width and height as a non-rotated character cell, so the vertical column rhythm, pagination (`charsPerColumn`), highlight backgrounds, mark sidebars, and hit-test rectangles remain consistent. (`RotatedBox` SHALL NOT be used, because it swaps the child's width and height during layout and would shrink the cell height for narrow punctuation.) The original character SHALL be preserved (no character substitution), so that character count and text offsets remain unchanged for search and TTS highlight mapping. The set of rotation-target characters SHALL be defined in the data layer (`vertical_char_map.dart`) alongside the existing character map, and a helper SHALL determine whether a given character belongs to the rotation set. Rotation-target characters SHALL NOT have entries in `verticalCharMap` (they SHALL bypass `mapToVerticalChar`). Both the main vertical text renderer and the ruby renderer SHALL apply this rotation consistently.

The rotation-target characters SHALL be:
- Double quotes: `"` (U+0022), `＂` (U+FF02), `"` (U+201C), `"` (U+201D)
- Single quotes / apostrophes: `'` (U+0027), `＇` (U+FF07), `'` (U+2018), `'` (U+2019)
- Backticks: `` ` `` (U+0060), `｀` (U+FF40)
- Colons: `:` (U+003A), `：` (U+FF1A)
- Semicolons: `;` (U+003B), `；` (U+FF1B)

#### Scenario: Double quotes are rotated 90 degrees clockwise
- **WHEN** any of `"`, `＂`, `"`, `"` are encountered in vertical mode
- **THEN** the original character is rendered rotated 90° clockwise via `Transform.rotate` (angle π/2) within its fixed-size cell whose dimensions match a non-rotated character cell, and the character is NOT substituted

#### Scenario: Single quotes and apostrophes are rotated 90 degrees clockwise
- **WHEN** any of `'`, `＇`, `'`, `'` are encountered in vertical mode
- **THEN** the original character is rendered rotated 90° clockwise via `Transform.rotate` (angle π/2) within its fixed-size cell whose dimensions match a non-rotated character cell, and the character is NOT substituted

#### Scenario: Backticks are rotated 90 degrees clockwise
- **WHEN** `` ` `` or `｀` are encountered in vertical mode
- **THEN** the original character is rendered rotated 90° clockwise via `Transform.rotate` (angle π/2) within its fixed-size cell whose dimensions match a non-rotated character cell, and the character is NOT substituted

#### Scenario: Colons and semicolons are rotated 90 degrees clockwise
- **WHEN** any of `:`, `：`, `;`, `；` are encountered in vertical mode
- **THEN** the original character is rendered rotated 90° clockwise via `Transform.rotate` (angle π/2) within its fixed-size cell whose dimensions match a non-rotated character cell, so the colon's dots appear side by side, and the character is NOT substituted

#### Scenario: Rotation preserves the original character
- **WHEN** a rotation-target character is rendered in vertical mode
- **THEN** the underlying character value is unchanged (no substitution occurs), so character count and text offsets used for search and TTS highlight mapping are identical to the source text

#### Scenario: Rotation preserves the character cell dimensions
- **WHEN** a rotation-target character and a non-rotated character are rendered in the same vertical text with the same font size
- **THEN** the rotation-target character's cell SHALL have the same height as the non-rotated character's cell, so the vertical column rhythm is not shrunk by the rotation

#### Scenario: Rotation applies in ruby rendering
- **WHEN** a rotation-target character appears as a ruby base character or ruby annotation character in vertical mode
- **THEN** the character is rendered with the same 90° clockwise rotation as in the main vertical text renderer

## MODIFIED Requirements

### Requirement: Vertical character mapping
The system SHALL replace horizontal-specific characters with their vertical writing equivalents when rendering in vertical mode. The mapping SHALL cover the full set defined in the Qiita reference article's VerticalRotated class, plus NovelViewer-specific additions. Colons (`:`, `：`) and semicolons (`;`, `；`) SHALL NOT be part of this substitution map; they are handled by physical rotation as defined in the "Vertical punctuation rotation" requirement.

#### Scenario: Punctuation is mapped to vertical form
- **WHEN** punctuation characters `。`, `、`, `,`, `､` are encountered in vertical mode
- **THEN** they are rendered as `︒`, `︑`, `︐`, `︑` respectively

#### Scenario: Long vowel marks and dashes are mapped to vertical bar
- **WHEN** any of `ー`, `ｰ`, `-`, `_`, `−`, `－`, `─`, `—` are encountered in vertical mode
- **THEN** they are rendered as `丨` (CJK unified ideograph U+4E28)

#### Scenario: Wave dashes are mapped to vertical form
- **WHEN** `〜` or `～` are encountered in vertical mode
- **THEN** they are rendered as `丨`

#### Scenario: Arrows are rotated 90 degrees
- **WHEN** arrow characters `↑`, `↓`, `←`, `→` are encountered in vertical mode
- **THEN** they are rendered as `→`, `←`, `↑`, `↓` respectively (rotated 90° clockwise)

#### Scenario: Brackets are mapped to vertical forms
- **WHEN** bracket characters are encountered in vertical mode
- **THEN** they are mapped as follows:
  - Corner brackets: `「」｢｣` → `﹁﹂`, `『』` → `﹃﹄`
  - Parentheses: `（）()` → `︵︶`
  - Square brackets: `［］[]` → `﹇﹈`
  - Curly brackets: `｛｝{}` → `︷︸`
  - Lenticular brackets: `【】` → `︻︼`, `〖〗` → `︗︘`
  - Angle brackets: `＜＞<>` → `︿﹀`, `〈〉` → `︿﹀`, `《》` → `︽︾`
  - Tortoise shell brackets: `〔〕` → `︹︺`

#### Scenario: Colons and semicolons are rotated, not substituted
- **WHEN** `：`, `:`, `；`, or `;` are encountered in vertical mode
- **THEN** they are NOT substituted via `verticalCharMap`, and are instead rendered by physical 90° clockwise rotation as defined in the "Vertical punctuation rotation" requirement

#### Scenario: Equals signs are mapped to vertical form
- **WHEN** `＝` or `=` are encountered in vertical mode
- **THEN** they are rendered as `॥`

#### Scenario: Ellipsis and two-dot leader are mapped to vertical form
- **WHEN** `…` or `‥` are encountered in vertical mode
- **THEN** they are rendered as `︙` or `︰` respectively

#### Scenario: Slash is mapped to vertical form
- **WHEN** `／` is encountered in vertical mode
- **THEN** it is rendered as `＼`

#### Scenario: Space is mapped to ideographic space
- **WHEN** a half-width space `' '` is encountered in vertical mode
- **THEN** it is rendered as a full-width ideographic space `'　'`

#### Scenario: Unmapped characters remain unchanged
- **WHEN** a character without a vertical mapping is encountered in vertical mode
- **THEN** the character is rendered as-is without transformation
