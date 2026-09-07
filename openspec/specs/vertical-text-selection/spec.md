## Purpose

Text selection by drag from any pointer in vertical display mode: hit-test via per-character `GlobalKey` rectangles, vertical reading-order range expansion, original-character extraction (Ruby base text, unmapped originals), blue selection highlight (yielding to yellow search highlight), auto-clear on page navigation, and a context menu (Copy / 辞書追加) opened by a right click or, from a pointer with no secondary button, by a tap inside the selection.
## Requirements
### Requirement: Vertical text selection by drag
The system SHALL allow the user to select text in vertical display mode by click-and-drag gesture. The selection SHALL follow the vertical reading direction (top-to-bottom within a column, right-to-left across columns). The selection range SHALL be determined by mapping the pointer position to character indices using actual rendered widget rectangles collected via `GlobalKey` and `RenderBox`. During drag updates, the system SHALL snap to the nearest character region when the pointer is between characters.

The rectangles SHALL be collected relative to `VerticalTextPage`'s own render box, so that they stay correct when that render box is larger than the rendered text and the text is aligned inside it. A pointer position SHALL be resolved against those rectangles without any additional coordinate correction.

The selection anchor SHALL be resolved from the position where the pointer went down, NOT from the position `onPanStart` reports. When `onPanStart` decides the gesture is a selection, the range SHALL also be extended to the position `onPanStart` reports: no update event follows the move that got the pan accepted, so a drag accepted and released without a further move would otherwise select only the pressed character and drop everything the pointer crossed. A pan is accepted only after the gesture's slop distance, which on a touchscreen is worth a character or two of vertical text, so anchoring at acceptance would drop the characters the reader started on and would let a drag that began outside the text anchor on a character it merely passed.

Resolving the anchor SHALL snap to the nearest character within the width of a column gap, exactly as the tap path does: nothing is painted between two columns, but a finger aimed at a character lands there often enough, and an anchor that resolves to nothing abandons the whole drag and clears any selection that was already there.

A drag that begins over an area where no character is painted, farther than a column gap from any character, SHALL NOT start a selection, because no anchor character can be resolved there. Such a drag SHALL still be eligible for swipe detection as defined in the vertical-text-display capability.

The rectangles SHALL be rebuilt whenever the page's own size changes, not only when its segments, text style or column spacing change: the text is aligned inside the page, so every rectangle moves when the page resizes even though none of those inputs has.

A tap without dragging SHALL clear the selection, except where a tap from a pointer with no secondary button (touch or stylus) lands inside the current selection, which opens the selection context menu and leaves the selection intact. Resolving where such a tap landed SHALL snap to the nearest character within the width of a column gap, so that the unpainted gap between two selected columns counts as inside the selection; beyond that distance the tap SHALL resolve to nothing and so still clear. This SHALL hold for the empty area of the page as well: a tap there is farther than a column gap from any character, so it resolves to nothing and clears the selection. The gesture recognizers used here SHALL NOT be changed to support that: no long-press recognizer SHALL be added, because a long press accepted after its deadline forcibly removes the pan recognizer from the gesture arena and would abandon a selection drag that began with the finger held still.

#### Scenario: User selects text by dragging in vertical mode
- **WHEN** the user clicks and drags over characters in vertical display mode
- **THEN** the characters within the drag range are visually highlighted with a selection color

#### Scenario: Selection follows vertical reading order
- **WHEN** the user drags from a character in the right column to a character in the left column
- **THEN** all characters between the start and end positions are selected following top-to-bottom, right-to-left order

#### Scenario: Selection within a single column
- **WHEN** the user drags vertically within a single column
- **THEN** only the characters between the start and end positions within that column are selected

#### Scenario: Selection hit testing is unaffected by the page render box growing
- **WHEN** the user selects text on a page whose text occupies only part of the available width, so the rendered text sits at the top-right of a larger render box
- **THEN** the characters under the pointer are selected exactly as they are on a page whose text fills the width

#### Scenario: A drag starting over empty area starts no selection
- **WHEN** the user starts a primarily vertical drag from an area of the page where no character is painted
- **THEN** no selection is started and no selection highlight is displayed

#### Scenario: A selection starts at the character the pointer went down on
- **WHEN** the reader presses on a character and drags far enough for the pan to be accepted
- **THEN** the selection includes the character that was pressed, not only the ones past the slop distance

#### Scenario: A drag accepted and released in one move selects the whole span
- **WHEN** the pointer goes down on a character, moves once far enough for the pan to be accepted, and is released with no further movement
- **THEN** the selection runs from the pressed character to the one under the release, not just the pressed character

#### Scenario: A press in the gap between two columns still selects
- **WHEN** the reader presses in the unpainted gap between two columns and drags
- **THEN** the anchor snaps to the nearest character and the drag selects normally

#### Scenario: A drag beginning beside the text starts no selection
- **WHEN** the reader presses just outside the text, within the gesture's slop distance of a column, and drags onto that column
- **THEN** no selection is started, because the anchor is decided by where the pointer went down

#### Scenario: Tap clears existing selection
- **WHEN** the user taps without dragging outside the selected range while a selection exists
- **THEN** the selection is cleared

#### Scenario: A tap on the empty area of the page clears the selection
- **WHEN** the user taps an area of the page where no character is painted while a selection exists
- **THEN** the selection is cleared

#### Scenario: A mouse click inside the selection clears it
- **WHEN** the user clicks with a mouse inside the selected range
- **THEN** the selection is cleared

#### Scenario: A touch tap inside the selection does not clear it
- **WHEN** the user taps with a finger inside the selected range
- **THEN** the selection is retained

### Requirement: Selected text extraction in vertical mode
The system SHALL extract the original (unmapped) text from the selected range and store it in the application state via `selectedTextProvider`. For ruby-annotated text, the base text (e.g., kanji) SHALL be used as the selected text content. When the selected range crosses a "visual line break" inserted by pagination to wrap a long line across columns, the system SHALL NOT insert a newline character at that boundary, so the extracted text remains a continuous string. A "real" paragraph break (corresponding to a `\n` in the original text) SHALL still produce a newline in the extracted text. The system SHALL distinguish the two using the set of real line-break entries (`lineBreakEntryIndices`); when that set is not provided, every newline entry SHALL be treated as a real break for backward compatibility.

Together with the extracted text, the system SHALL report the selection's start offset in plain-text coordinates. The offset SHALL be computed by walking the character entries up to the selection start, counting a ruby entry as the length of its base text, counting a real line-break entry as one character, and counting a visual line-break entry as zero characters. The resulting page-local offset SHALL be added to the page's start offset (`pageStartTextOffset`) so that the value stored in application state is a document-global plain-text offset.

#### Scenario: Selected text is stored in application state
- **WHEN** the user completes a text selection in vertical mode
- **THEN** the selected text is stored in `selectedTextProvider` and accessible to other features (e.g., search)

#### Scenario: Selection start offset is stored alongside the text
- **WHEN** the user completes a text selection in vertical mode
- **THEN** the stored selection state carries the document-global plain-text offset of the selection start

#### Scenario: Offset on a later page includes the page start offset
- **WHEN** the user selects text on a page whose `pageStartTextOffset` is 800, at a position 40 plain-text characters into that page
- **THEN** the stored offset is 840

#### Scenario: Offset counts ruby entries as their base length
- **WHEN** the selection start is preceded by a ruby entry whose base text is 2 characters long
- **THEN** the offset advances by 2 for that entry, not by 1 and not by the length of the ruby reading

#### Scenario: Offset ignores visual column breaks
- **WHEN** the selection start is preceded by a visual line break inserted by pagination to wrap a long line
- **THEN** the offset does not advance for that break, while a real paragraph break advances it by one

#### Scenario: Ruby text selection extracts base text
- **WHEN** the user selects a range that includes ruby-annotated text
- **THEN** the extracted text contains the base text (e.g., kanji), not the ruby annotation

#### Scenario: Mapped characters are extracted as originals
- **WHEN** the user selects text that includes vertically mapped characters (e.g., `︒` displayed for `。`)
- **THEN** the extracted text contains the original characters (e.g., `。`), not the display-mapped characters

#### Scenario: Selection cleared updates provider
- **WHEN** the selection is cleared (by tap or page change)
- **THEN** `selectedTextProvider` is set to null

#### Scenario: Selection crossing a visual column break has no newline
- **WHEN** the user selects a word that straddles a visual line break inserted to wrap a long line across columns (e.g. "アリ" at the end of one column and "ス" at the top of the next column, where that boundary is a visual break)
- **THEN** the extracted text is the continuous string "アリス" with no newline character inserted at the column boundary

#### Scenario: Selection crossing a real paragraph break keeps the newline
- **WHEN** the user selects a range that spans a real paragraph break (a `\n` present in the original text)
- **THEN** the extracted text contains a newline character at that boundary

### Requirement: Selection visual feedback in vertical mode
The system SHALL display selected characters with a visually distinct background color that differs from the search highlight color. The selection highlight SHALL use a semi-transparent blue background (`Colors.blue` with opacity 0.3). Search highlights (yellow) SHALL take precedence when both selection and search highlight apply to the same character.

#### Scenario: Selected characters are highlighted with blue background
- **WHEN** characters are within the selection range
- **THEN** they are displayed with a semi-transparent blue background color

#### Scenario: Search highlight takes precedence over selection
- **WHEN** a character is both within the selection range and matches the active search query
- **THEN** the character is displayed with the search highlight color (yellow), not the selection color

#### Scenario: Non-selected characters have no selection highlight
- **WHEN** characters are outside the selection range
- **THEN** they are displayed with their normal background (or search highlight if applicable)

### Requirement: Selection state cleared on page navigation
The system SHALL clear the text selection when the user navigates to a different page in vertical display mode.

A recognized swipe SHALL clear the selection and report the clearing through `onSelectionChanged`, whether or not the page index actually changes. The report SHALL cover an owner-supplied selection (`selectionStart`/`selectionEnd`) as well as the page's own: the page cannot clear the owner's props itself, so the report is how the owner learns to drop it — the same contract a tap already follows. The visual clearing and the reported state SHALL NOT diverge: `VerticalTextPage` SHALL report the clearing itself when it clears its own selection, rather than relying on `VerticalTextViewer` to report it after a successful page move, because a swipe at the first or last page is routed to the file-boundary handler and never reaches that report.

#### Scenario: Page forward clears selection
- **WHEN** the user presses the left arrow key to advance to the next page while text is selected
- **THEN** the selection is cleared and `selectedTextProvider` is set to null

#### Scenario: Page backward clears selection
- **WHEN** the user presses the right arrow key to go to the previous page while text is selected
- **THEN** the selection is cleared and `selectedTextProvider` is set to null

#### Scenario: A swipe at a page boundary clears the reported selection
- **WHEN** the user swipes on the last page while text is selected, so the page index stays where it is and the file-boundary handler takes over
- **THEN** the selection highlight is removed AND `selectedTextProvider` is set to null, so no feature keeps acting on text that is no longer shown as selected

### Requirement: 縦書き表示のコンテキストメニュー
縦書き閲覧画面でテキストを選択した状態で右クリックすると、「コピー」と「辞書追加」のメニュー項目を含むポップアップメニューを表示しなければならない（SHALL）。同じメニューは、選択範囲の内側を指でタップした場合にも表示しなければならない（SHALL）。テキストが選択されていない場合はメニューを表示してはならない（SHALL NOT）。

指によるタップという入口は、マウスの副ボタンを持たない端末のために設けるものであり、ポインタ種別が touch または stylus の場合に限らなければならない（SHALL）。マウスによるタップは従来どおり選択解除として扱わなければならない（SHALL）。タップ位置の判定は、列間の間隔と同じ距離までは最寄りの文字に吸着させなければならない（SHALL）——列と列の間には何も描画されておらず、指で文字を狙うとそこに落ちることが多いためである。その距離を超えた場合は吸着させてはならず（SHALL NOT）、余白のタップは従来どおり選択解除として扱われる。

いずれの入口から開いた場合も、メニューの項目・並び・動作は同一でなければならない（SHALL）。項目が欠ける理由は、実行中のプラットフォームが当該機能に対応していないこと（TTS・LLM 解析）に限られなければならない（SHALL）。

#### Scenario: 縦書きでテキスト選択後に右クリックでメニューが表示される
- **WHEN** 縦書き閲覧画面でテキストを選択した状態で右クリックする
- **THEN** 右クリック位置に「コピー」と「辞書追加」のメニュー項目を含むポップアップメニューが表示される

#### Scenario: 縦書きで選択範囲の内側を指でタップするとメニューが表示される
- **WHEN** 縦書き閲覧画面でテキストを選択した状態で、選択範囲の内側を指でタップする
- **THEN** タップ位置に右クリック時と同じ項目のポップアップメニューが表示され、選択は維持される

#### Scenario: 縦書きで選択範囲の外側を指でタップしてもメニューは表示されない
- **WHEN** 縦書き閲覧画面でテキストを選択した状態で、選択範囲の外側を指でタップする
- **THEN** ポップアップメニューは表示されず、選択が解除される

#### Scenario: 縦書きで選択中の列と列の間をタップするとメニューが表示される
- **WHEN** 縦書き閲覧画面で、いずれも選択範囲に含まれる 2 つの列の間の余白を指でタップする
- **THEN** タップ位置に選択メニューが表示され、選択は維持される

#### Scenario: 縦書きでスタイラスのタップも指と同じに扱われる
- **WHEN** 縦書き閲覧画面でテキストを選択した状態で、選択範囲の内側をスタイラスでタップする
- **THEN** 指でタップした場合と同じ選択メニューが表示される

#### Scenario: 縦書きでテキスト未選択時に右クリックしてもメニューは表示されない
- **WHEN** 縦書き閲覧画面でテキストが選択されていない状態で右クリックする
- **THEN** ポップアップメニューは表示されない

#### Scenario: 縦書きでテキスト未選択時に指でタップしてもメニューは表示されない
- **WHEN** 縦書き閲覧画面でテキストが選択されていない状態で指でタップする
- **THEN** ポップアップメニューは表示されない

#### Scenario: 縦書きでコピーを選択するとクリップボードにコピーされる
- **WHEN** ポップアップメニューの「コピー」を選択する
- **THEN** 選択テキストがシステムクリップボードにコピーされる

#### Scenario: 縦書きで辞書追加を選択するとダイアログが開く
- **WHEN** ポップアップメニューの「辞書追加」を選択する
- **THEN** 選択テキストが表記欄にプリセットされた辞書ダイアログが表示される

#### Scenario: 縦書きで辞書ダイアログを閉じると閲覧画面に戻る
- **WHEN** 辞書ダイアログを閉じる
- **THEN** 閲覧画面に戻り、通常の閲覧操作を継続できる

