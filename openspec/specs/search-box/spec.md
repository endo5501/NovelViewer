## Purpose

検索ボックスUIの表示制御、検索実行、および閉じる操作に関する仕様。

## Requirements

### Requirement: Search box display control
検索ボックスはCtrl+F/Cmd+Fでテキスト未選択時に表示されなければならない（SHALL）。検索ボックスが表示されると、テキスト入力フィールドに自動的にフォーカスが移動しなければならない（SHALL）。

#### Scenario: Show search box when no text is selected
- **WHEN** ユーザーがテキストを選択していない状態でCtrl+F（またはCmd+F）を押す
- **THEN** 検索ボックスが右カラムのSearchResultsPanel上部に表示され、テキスト入力フィールドにフォーカスが当たる

#### Scenario: Right column auto-show on search box activation
- **WHEN** 右カラムが非表示の状態でユーザーがテキスト未選択でCtrl+F（またはCmd+F）を押す
- **THEN** 右カラムが自動的に表示され、検索ボックスが表示される

#### Scenario: Search box not shown when text is selected
- **WHEN** ユーザーがテキストを選択した状態でCtrl+F（またはCmd+F）を押す
- **THEN** 検索ボックスは表示されず、選択テキストで即時検索が実行される（従来動作）

### Requirement: Search execution from search box
検索ボックスに入力された文字列でEnterキーを押すと検索が実行されなければならない（SHALL）。検索結果はSearchResultsPanelに表示されなければならない（SHALL）。

#### Scenario: Execute search on Enter key
- **WHEN** ユーザーが検索ボックスにテキストを入力しEnterキーを押す
- **THEN** 入力されたテキストで全ファイルに対する検索が実行され、結果がSearchResultsPanelに表示される

#### Scenario: Empty search query
- **WHEN** ユーザーが検索ボックスに何も入力せずEnterキーを押す
- **THEN** 検索は実行されず、既存の検索結果がクリアされる

### Requirement: Search box dismiss
検索ボックスはEscキーで閉じることができなければならない（SHALL）。検索ボックスを閉じると検索クエリがクリアされ、検索結果も消去されなければならない（SHALL）。

#### Scenario: Dismiss search box with Escape key
- **WHEN** 検索ボックスにフォーカスがある状態でEscキーを押す
- **THEN** 検索ボックスが非表示になり、検索クエリがクリアされ、検索結果が消去される

#### Scenario: Focus returns to main content after dismiss
- **WHEN** 検索ボックスをEscキーで閉じる
- **THEN** フォーカスがメインコンテンツ（テキストビューア）に戻る
