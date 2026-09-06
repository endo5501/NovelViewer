## MODIFIED Requirements

### Requirement: Vertical text selection by drag
The system SHALL allow the user to select text in vertical display mode by click-and-drag gesture. The selection SHALL follow the vertical reading direction (top-to-bottom within a column, right-to-left across columns). The selection range SHALL be determined by mapping the pointer position to character indices using actual rendered widget rectangles collected via `GlobalKey` and `RenderBox`. During drag updates, the system SHALL snap to the nearest character region when the pointer is between characters.

A tap without dragging SHALL clear the selection, except where a tap from a pointer with no secondary button (touch or stylus) lands inside the current selection, which opens the selection context menu and leaves the selection intact. Resolving where such a tap landed SHALL snap to the nearest character within the width of a column gap, so that the unpainted gap between two selected columns counts as inside the selection; beyond that distance the tap SHALL resolve to nothing and so still clear. The gesture recognizers used here SHALL NOT be changed to support that: no long-press recognizer SHALL be added, because a long press accepted after its deadline forcibly removes the pan recognizer from the gesture arena and would abandon a selection drag that began with the finger held still.

#### Scenario: User selects text by dragging in vertical mode
- **WHEN** the user clicks and drags over characters in vertical display mode
- **THEN** the characters within the drag range are visually highlighted with a selection color

#### Scenario: Selection follows vertical reading order
- **WHEN** the user drags from a character in the right column to a character in the left column
- **THEN** all characters between the start and end positions are selected following top-to-bottom, right-to-left order

#### Scenario: Selection within a single column
- **WHEN** the user drags vertically within a single column
- **THEN** only the characters between the start and end positions within that column are selected

#### Scenario: Tap clears existing selection
- **WHEN** the user taps without dragging outside the selected range while a selection exists
- **THEN** the selection is cleared

#### Scenario: A mouse click inside the selection clears it
- **WHEN** the user clicks with a mouse inside the selected range
- **THEN** the selection is cleared

#### Scenario: A touch tap inside the selection does not clear it
- **WHEN** the user taps with a finger inside the selected range
- **THEN** the selection is retained

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
