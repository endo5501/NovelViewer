## ADDED Requirements

### Requirement: Vertical text rendering
The system SHALL render text content in vertical writing mode (top-to-bottom, right-to-left columns) using a Wrap widget with vertical axis direction and RTL text direction. Each character SHALL be rendered individually as a separate widget within the Wrap layout. Each character widget SHALL be wrapped in a fixed-width container (`SizedBox`) with width equal to the current font size, and the character SHALL be horizontally centered within that container using a `Center` widget. This ensures consistent column alignment regardless of platform-specific font metrics differences. Characters SHALL be rendered with compact vertical spacing by setting the TextStyle `height` property to approximately 1.1 and minimizing the Wrap `spacing` to avoid excessive gaps between characters. The Wrap widget's `runSpacing` SHALL use the column spacing value from the settings (default `8.0`) instead of a hardcoded constant. The `VerticalTextPage` SHALL accept a `columnSpacing` parameter to control the `runSpacing` value. The Wrap widget SHALL be wrapped in a GestureDetector to support text selection via drag gestures. The `VerticalTextPage` SHALL accept an `onSelectionChanged` callback. Each character widget SHALL be assigned a `GlobalKey` to enable post-layout collection of actual rendered rectangles for accurate hit testing.

#### Scenario: Text is displayed vertically
- **WHEN** the display mode is set to vertical
- **THEN** characters are arranged from top to bottom within each column, and columns flow from right to left

#### Scenario: Line breaks create new columns
- **WHEN** the text content contains newline characters in vertical mode
- **THEN** a new column starts at the position of each newline, with subsequent text continuing from the top of the new column

#### Scenario: Empty line creates a visible empty column
- **WHEN** the text content contains consecutive newline characters (blank line) in vertical mode
- **THEN** an empty column SHALL be rendered with the same width as a text column (one character width), creating visible space between adjacent text columns

#### Scenario: Column overflow wraps to next column
- **WHEN** a column of text exceeds the available vertical height
- **THEN** the remaining characters wrap to a new column to the left

#### Scenario: GestureDetector wraps the vertical text layout
- **WHEN** the vertical text page is rendered
- **THEN** a GestureDetector is present as a parent of the Wrap widget to capture pan gestures for text selection

#### Scenario: Characters are horizontally centered in fixed-width containers
- **WHEN** any character is rendered in vertical text mode
- **THEN** the character SHALL be placed inside a SizedBox with width equal to the current font size, and the character SHALL be horizontally centered within that SizedBox

#### Scenario: Column alignment is consistent across platforms
- **WHEN** vertical text is rendered on different platforms (macOS, Windows)
- **THEN** characters within each column SHALL be aligned vertically in a straight line regardless of individual character width differences in the platform's font

#### Scenario: Ruby base and annotation characters use fixed-width containers
- **WHEN** ruby text (base and annotation) is rendered in vertical mode
- **THEN** each base character SHALL be wrapped in a SizedBox with width equal to the base font size, and each ruby annotation character SHALL be wrapped in a SizedBox with width equal to the ruby font size, both horizontally centered

#### Scenario: Column spacing uses configurable value
- **WHEN** the vertical text page is rendered with a `columnSpacing` parameter
- **THEN** the Wrap widget's `runSpacing` SHALL be set to the provided `columnSpacing` value

#### Scenario: Default column spacing
- **WHEN** the vertical text page is rendered without an explicit `columnSpacing` parameter
- **THEN** the Wrap widget's `runSpacing` SHALL use the default value of `8.0`

### Requirement: Vertical character mapping
The system SHALL replace horizontal-specific characters with their vertical writing equivalents when rendering in vertical mode. The mapping SHALL cover the full set defined in the Qiita reference article's VerticalRotated class, plus NovelViewer-specific additions.

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

#### Scenario: Colons and semicolons are mapped to vertical form
- **WHEN** `：`, `:`, `；`, or `;` are encountered in vertical mode
- **THEN** they are rendered as `︓`, `︓`, `︔`, `︔` respectively

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

### Requirement: Vertical text pagination
The system SHALL display vertical text in pages rather than as a scrollable area. Page boundaries SHALL be calculated dynamically based on both the available width and height of the display area. The pagination SHALL account for the fact that a single logical line (newline-separated text) may occupy multiple visual columns when its character count exceeds the available vertical height. Character dimensions (width and height) used for pagination calculations SHALL be measured from actual font metrics using TextPainter with a representative CJK character, rather than estimated from fontSize alone, to ensure pagination matches the Wrap widget's rendering across all font families and sizes. The maximum columns per page calculation SHALL account for the Wrap widget's runSpacing being applied on both sides of column-break sentinel widgets, resulting in an effective inter-column spacing of `2 * runSpacing` rather than `1 * runSpacing`. The `VerticalTextViewer` SHALL accept a `columnSpacing` parameter and use it in pagination calculations instead of a hardcoded constant. The vertical text display area SHALL be clipped to prevent any overflow from becoming visible beyond the display boundaries. Column character counts SHALL NOT exceed `charsPerColumn` but MAY be shorter (typically by 1 character) due to kinsoku push-out adjustments.

#### Scenario: Text is split into pages
- **WHEN** the text content exceeds the available display area in vertical mode
- **THEN** the text is divided into pages, each fitting within the display area without overflowing

#### Scenario: Long line spans multiple visual columns
- **WHEN** a single logical line contains more characters than can fit in the available vertical height
- **THEN** the pagination accounts for the multiple visual columns that line will occupy, preventing horizontal overflow

#### Scenario: Page boundary adjusts to window size
- **WHEN** the application window is resized while in vertical display mode
- **THEN** the page boundaries are recalculated to fit the new display area

#### Scenario: Current page indicator is displayed
- **WHEN** a paginated vertical text is displayed
- **THEN** the current page number and total page count are shown (e.g., "3 / 15")

#### Scenario: Pagination uses measured font metrics
- **WHEN** the pagination calculates column widths and characters per column
- **THEN** the character width and height are obtained by measuring a representative character ('あ') with the current TextStyle via TextPainter, not by estimating from fontSize

#### Scenario: Pagination remains accurate across font families
- **WHEN** the user switches between different font families (e.g., system default, Hiragino Mincho, YuGothic)
- **THEN** the pagination recalculates using the new font's actual metrics and text does not overflow the display area

#### Scenario: Pagination remains accurate across font sizes
- **WHEN** the user changes font size (anywhere in the 10.0-32.0 range)
- **THEN** the pagination recalculates using the actual rendered dimensions and text does not overflow the display area

#### Scenario: Column count accounts for sentinel runSpacing
- **WHEN** the pagination calculates the maximum number of columns per page
- **THEN** the calculation SHALL account for the double runSpacing caused by column-break sentinel widgets in the Wrap layout

#### Scenario: Display area is clipped to prevent overflow
- **WHEN** the vertical text page is rendered
- **THEN** the display area SHALL be clipped so that any content exceeding the boundaries is not visible to the user

#### Scenario: Empty columns from blank lines occupy full column width
- **WHEN** the text contains blank lines (paragraph separators) that produce empty columns
- **THEN** the pagination SHALL treat empty columns with the same width as non-empty columns (one character width), so that blank lines are visually represented as empty space between text columns
- **AND** the actual rendered width of all columns on a page SHALL be less than or equal to the available display width

#### Scenario: Page navigation with blank lines remains accurate
- **WHEN** the user navigates to a specific line number in text containing blank lines
- **THEN** the viewer SHALL correctly identify which page contains the target line, accounting for the columns per page

#### Scenario: Columns with kinsoku adjustment fit within page width
- **WHEN** the pagination groups columns into pages and some columns have variable character counts due to kinsoku processing
- **THEN** the pagination SHALL use the actual character count of each column for width calculation, ensuring columns fit within the available page width

#### Scenario: Pagination uses configurable column spacing
- **WHEN** the `VerticalTextViewer` is rendered with a `columnSpacing` parameter
- **THEN** the pagination calculation SHALL use the provided `columnSpacing` value instead of a hardcoded constant

#### Scenario: Column spacing change triggers re-pagination
- **WHEN** the column spacing setting is changed while vertical text is displayed
- **THEN** the pagination SHALL be recalculated with the new column spacing value and the display SHALL update accordingly

### Requirement: Arrow key page navigation
The system SHALL support left and right arrow key presses to navigate between pages in vertical display mode. The left arrow key SHALL advance to the next page and the right arrow key SHALL go to the previous page, matching the right-to-left reading direction of vertical Japanese text. Page transitions SHALL be accompanied by a slide animation as defined in the page-transition-animation capability.

#### Scenario: Left arrow advances to next page
- **WHEN** the user presses the left arrow key in vertical mode
- **THEN** the display advances to the next page with a slide animation (current page slides right, new page slides in from the left)

#### Scenario: Right arrow returns to previous page
- **WHEN** the user presses the right arrow key in vertical mode
- **THEN** the display returns to the previous page with a slide animation (current page slides left, new page slides in from the right)

#### Scenario: Left arrow on last page has no effect
- **WHEN** the user presses the left arrow key while on the last page
- **THEN** the display remains on the last page without any animation

#### Scenario: Right arrow on first page has no effect
- **WHEN** the user presses the right arrow key while on the first page
- **THEN** the display remains on the first page without any animation

### Requirement: Search highlight in vertical mode
The system SHALL highlight search query matches in vertical text mode by applying a distinct background color to matching characters.

#### Scenario: Highlight match in vertical text
- **WHEN** a search query is active and matches text in vertical display mode
- **THEN** the matching characters are highlighted with a distinct background color

#### Scenario: Highlight spans across column boundary
- **WHEN** a search query match spans characters that are split across two columns
- **THEN** the matching characters in both columns are highlighted

### Requirement: Swipe gesture page navigation
The system SHALL support horizontal swipe gestures to navigate between pages in vertical display mode. Swipe detection SHALL be implemented within `VerticalTextPage`'s `GestureDetector` (`onPan*` handlers), sharing the same gesture recognizer that handles text selection. The system SHALL use a gesture mode (`undecided`/`selecting`/`swiping`) to early-classify the user's intent based on the initial drag direction. On `onPanDown`, the system SHALL capture the true pointer-down position and reset the gesture mode to `undecided`. On `onPanStart`, the system SHALL record the anchor character index but SHALL NOT start visual text selection (deferred selection). On `onPanUpdate`, once the displacement from the start position exceeds 10 pixels (`_kGestureDecisionThreshold`), the system SHALL classify the gesture: if `|dx| > |dy|` the mode becomes `swiping` (no selection visual updates); otherwise the mode becomes `selecting` (deferred selection begins). On `onPanEnd`, if the mode is `swiping` or `undecided`, the system SHALL use `detectSwipeFromDrag` to determine if the gesture constitutes a swipe based on displacement and velocity from `DragEndDetails`; if the mode is `selecting`, the system SHALL notify the text selection result without attempting swipe detection. When velocity is available (fling detected, > 200 px/s), a swipe SHALL be recognized if absolute horizontal displacement exceeds 50 pixels (`kSwipeMinDistance`). When velocity is unavailable (desktop scenario where user stops before releasing, velocity ≈ 0), a swipe SHALL be recognized if absolute horizontal displacement exceeds 80 pixels (`kSwipeMinDistanceWithoutFling`). In both cases, the absolute horizontal displacement SHALL exceed the absolute vertical displacement. When a swipe is detected, the system SHALL clear any active text selection and invoke the `onSwipe` callback. `VerticalTextViewer` SHALL pass an `onSwipe` callback to `VerticalTextPage` to handle page navigation. The swipe direction-to-page mapping SHALL follow the "content dragging" metaphor consistent with horizontal mode scrolling: a right swipe (finger moves left-to-right, dx > 0) SHALL advance to the next page, and a left swipe (finger moves right-to-left, dx < 0) SHALL return to the previous page. This mirrors horizontal mode where swiping up reveals content below; in vertical text mode, swiping right reveals content to the left (the reading direction). Swipe detection thresholds SHALL be defined as named constants to facilitate future tuning. Page transitions triggered by swipe SHALL be accompanied by a slide animation as defined in the page-transition-animation capability.

#### Scenario: Right swipe advances to next page
- **WHEN** the user performs a right swipe (positive horizontal displacement, finger moves left-to-right) that meets all swipe criteria in vertical mode
- **THEN** the display advances to the next page with a slide animation (content dragging metaphor: drag content rightward to reveal next content on the left)

#### Scenario: Left swipe returns to previous page
- **WHEN** the user performs a left swipe (negative horizontal displacement, finger moves right-to-left) that meets all swipe criteria in vertical mode
- **THEN** the display returns to the previous page with a slide animation

#### Scenario: Right swipe on last page has no effect
- **WHEN** the user performs a right swipe on the last page in vertical mode
- **THEN** the display remains on the last page without any animation

#### Scenario: Left swipe on first page has no effect
- **WHEN** the user performs a left swipe on the first page in vertical mode
- **THEN** the display remains on the first page without any animation

#### Scenario: Slow horizontal drag is not recognized as swipe
- **WHEN** the user performs a horizontal drag with velocity below 200 pixels per second and distance below 80 pixels
- **THEN** the gesture is not recognized as a swipe and text selection operates normally

#### Scenario: Short horizontal movement is not recognized as swipe
- **WHEN** the user performs a horizontal movement with displacement below 50 pixels (with velocity) or below 80 pixels (without velocity)
- **THEN** the gesture is not recognized as a swipe and text selection operates normally

#### Scenario: Primarily vertical drag is not recognized as swipe
- **WHEN** the user performs a drag where vertical displacement exceeds horizontal displacement
- **THEN** the gesture mode becomes `selecting` and text selection operates normally without attempting swipe detection

#### Scenario: Swipe clears active text selection
- **WHEN** a swipe gesture is detected while text is selected
- **THEN** the active text selection is cleared

#### Scenario: Desktop drag with pause before release triggers swipe
- **WHEN** the user drags horizontally more than 80 pixels and pauses before releasing the mouse button (velocity drops to zero)
- **THEN** the gesture is recognized as a swipe using the distance-only fallback threshold

#### Scenario: Horizontal drag does not show selection highlight
- **WHEN** the user performs a primarily horizontal drag (|dx| > |dy| after 10px displacement)
- **THEN** the gesture mode becomes `swiping` and no text selection highlight is displayed during the drag

#### Scenario: Text selection drag does not trigger swipe
- **WHEN** the user performs a primarily vertical or diagonal drag for text selection (|dy| >= |dx| after 10px displacement)
- **THEN** the gesture mode becomes `selecting` and swipe detection is not attempted at pan end

#### Scenario: Very short drag below decision threshold
- **WHEN** the user performs a drag with total displacement below 10 pixels before releasing
- **THEN** the gesture mode remains `undecided`, no text selection highlight is shown, and swipe detection is attempted but does not qualify due to insufficient distance

#### Scenario: Arrow key navigation continues to work alongside swipe
- **WHEN** the user presses left or right arrow keys in vertical mode with swipe support enabled
- **THEN** the arrow key page navigation works identically with slide animation

### Requirement: Mouse wheel page navigation
The system SHALL support mouse wheel (scroll) events to navigate between pages in vertical display mode. The `VerticalTextViewer` widget's `Listener` SHALL handle `PointerScrollEvent` via the `onPointerSignal` callback. A downward scroll (`scrollDelta.dy > 0`) SHALL advance to the next page, and an upward scroll (`scrollDelta.dy < 0`) SHALL return to the previous page. This mapping matches the horizontal mode convention where scrolling down reveals further content. Page transitions triggered by wheel events SHALL use the same slide animation as arrow key and swipe navigation (via `_changePage`). The system SHALL ignore wheel events while a page transition animation is in progress (`AnimationController.isAnimating`) to prevent unintended multi-page advancement from rapid scroll events.

#### Scenario: Wheel scroll down advances to next page
- **WHEN** the user scrolls the mouse wheel downward (positive `scrollDelta.dy`) in vertical mode
- **THEN** the display SHALL advance to the next page with a slide animation

#### Scenario: Wheel scroll up returns to previous page
- **WHEN** the user scrolls the mouse wheel upward (negative `scrollDelta.dy`) in vertical mode
- **THEN** the display SHALL return to the previous page with a slide animation

#### Scenario: Wheel scroll down on last page has no effect
- **WHEN** the user scrolls the mouse wheel downward while on the last page in vertical mode
- **THEN** the display SHALL remain on the last page without any animation

#### Scenario: Wheel scroll up on first page has no effect
- **WHEN** the user scrolls the mouse wheel upward while on the first page in vertical mode
- **THEN** the display SHALL remain on the first page without any animation

#### Scenario: Wheel events are ignored during page transition animation
- **WHEN** the user scrolls the mouse wheel while a page transition animation is in progress
- **THEN** the wheel event SHALL be ignored and no additional page transition SHALL be triggered

#### Scenario: Wheel navigation coexists with arrow key navigation
- **WHEN** the user alternates between mouse wheel scrolling and arrow key presses in vertical mode
- **THEN** both input methods SHALL trigger page transitions independently using the same underlying mechanism

#### Scenario: Wheel navigation coexists with swipe navigation
- **WHEN** the user alternates between mouse wheel scrolling and swipe gestures in vertical mode
- **THEN** both input methods SHALL trigger page transitions independently using the same underlying mechanism

#### Scenario: Non-scroll pointer signals are ignored
- **WHEN** a pointer signal event other than `PointerScrollEvent` is received (e.g., `PointerScaleEvent`)
- **THEN** the event SHALL be ignored and no page transition SHALL occur
