## ADDED Requirements

### Requirement: Search shortcut behavior branching
Ctrl+F（Windows/Linux）またはCmd+F（macOS）を押した際、テキスト選択状態に応じて動作が分岐しなければならない（SHALL）。テキストが選択されている場合は選択テキストで即時検索を実行し、テキストが選択されていない場合は検索ボックスを表示しなければならない（SHALL）。

#### Scenario: Ctrl+F with selected text performs immediate search
- **WHEN** ユーザーがテキストを選択した状態でCtrl+F（またはCmd+F）を押す
- **THEN** 選択テキストが検索クエリとして設定され、即座に検索が実行される

#### Scenario: Ctrl+F without selected text shows search box
- **WHEN** ユーザーがテキストを選択していない状態でCtrl+F（またはCmd+F）を押す
- **THEN** 検索ボックスが表示され、ユーザーが任意の文字列を入力できる状態になる
