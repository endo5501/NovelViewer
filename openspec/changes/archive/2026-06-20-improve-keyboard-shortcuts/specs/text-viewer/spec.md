## MODIFIED Requirements

### Requirement: Scrollable text area
In horizontal display mode, the text display area SHALL be scrollable to accommodate text files of any length. In vertical display mode, pagination SHALL be used instead of scrolling. In horizontal display mode, the text viewer SHALL respond to the logical `nextPage`/`prevPage` actions (default cursor keys: down/up) by scrolling the content by approximately one viewport height per activation, using an animated scroll. The page-scroll behavior SHALL apply only while the horizontal text viewer has keyboard focus.

#### Scenario: Long text file is scrollable in horizontal mode
- **WHEN** a text file whose content exceeds the visible area is displayed in horizontal mode
- **THEN** the user can scroll vertically to read the entire content

#### Scenario: Long text file is paginated in vertical mode
- **WHEN** a text file whose content exceeds the visible area is displayed in vertical mode
- **THEN** the text is displayed in pages navigable by arrow keys

#### Scenario: Page-forward by cursor key in horizontal mode
- **WHEN** 横書き表示でテキストビューアにフォーカスがあり、`nextPage`（既定の下カーソルキー）が押される
- **THEN** 表示内容がおよそ1画面分（ビューポート高さ）だけ下方向へアニメーションスクロールする

#### Scenario: Page-back by cursor key in horizontal mode
- **WHEN** 横書き表示でテキストビューアにフォーカスがあり、`prevPage`（既定の上カーソルキー）が押される
- **THEN** 表示内容がおよそ1画面分だけ上方向へアニメーションスクロールする

#### Scenario: No page-scroll when horizontal viewer lacks focus
- **WHEN** 横書き表示中にフォーカスがファイルブラウザにある状態でカーソルキーが押される
- **THEN** 横書きテキストビューアはページスクロールせず、フォーカスのある対象（ファイルブラウザ）がカーソル操作を処理する
