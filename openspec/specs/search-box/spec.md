## Purpose

検索ボックスUIの表示制御、検索の実行、フォーカス制御、Ctrl+F/Cmd+Fのトグルおよびエスケープによる閉じる操作（右カラムを含む）に関する仕様。検索ボックスは右カラムのSearchResultsPanel上部に表示される。

## Requirements

### Requirement: Search box display control
検索ボックスはCtrl+F/Cmd+Fでテキスト未選択時に表示されなければならない（SHALL）。検索ボックスが表示されると、テキスト入力フィールドに自動的にフォーカスが移動しなければならない（SHALL）。このフォーカス移動は、右カラムが直前まで非表示でSearchResultsPanelが未マウントだった場合（Ctrl+Fにより右カラムと同時に表示される場合）でも、初回表示時に確実に行われなければならない（SHALL）。

#### Scenario: Show search box when no text is selected
- **WHEN** ユーザーがテキストを選択していない状態でCtrl+F（またはCmd+F）を押す
- **THEN** 検索ボックスが右カラムのSearchResultsPanel上部に表示され、テキスト入力フィールドにフォーカスが当たる

#### Scenario: Right column auto-show on search box activation
- **WHEN** 右カラムが非表示の状態でユーザーがテキスト未選択でCtrl+F（またはCmd+F）を押す
- **THEN** 右カラムが自動的に表示され、検索ボックスが表示される

#### Scenario: Focus reaches the field on first activation from hidden right column
- **WHEN** 右カラムが非表示でSearchResultsPanelが未マウントの状態から、テキスト未選択でCtrl+F（またはCmd+F）を押す
- **THEN** 右カラムと検索ボックスが表示され、初回表示でテキスト入力フィールドにフォーカスが当たる

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
検索ボックスはEscキーで閉じることができなければならない（SHALL）。このEscによるクローズは、検索入力フィールドにフォーカスがある場合に作用しなければならない（SHALL）。検索ボックスを閉じると検索クエリがクリアされ、検索結果も消去されなければならない（SHALL）。さらに、右カラムは現在検索専用であるため、検索ボックスを閉じる際には右カラムも閉じられなければならない（SHALL）。フォーカス非依存でEscが検索を閉じる旧来のグローバル動作は廃止され、検索のクローズはCtrl+F（/Cmd+F）トグルと検索入力フィールド上のEscに限られなければならない（SHALL）。

#### Scenario: Dismiss search box with Escape key
- **WHEN** 検索入力フィールドにフォーカスがある状態でEscキーを押す
- **THEN** 検索ボックスが非表示になり、検索クエリと検索結果がクリアされ、右カラムも閉じられる

#### Scenario: Focus returns to main content after dismiss
- **WHEN** 検索入力フィールド上のEscキーで検索を閉じる
- **THEN** フォーカスがメインコンテンツ（テキストビューア）に戻る

#### Scenario: Escape does not close search when field is not focused
- **WHEN** フォーカスがテキストビューア等（検索入力フィールド以外）にある状態でEscキーを押す
- **THEN** 検索ボックスのクローズは発生しない（Escは検索以外の文脈、例えばTTS停止として扱われる）

### Requirement: Search shortcut toggle to dismiss
検索ショートカット（既定Ctrl+F/Cmd+F）はトグルとして動作しなければならない（SHALL）。検索ボックスが表示されている状態で再度検索ショートカットを押すと、検索ボックスが非表示になり、検索クエリと検索結果がクリアされ、さらに右カラムが閉じられなければならない（SHALL）。この閉じる動作はEscキーによる閉じる動作と同一のクローズ処理を共有しなければならない（SHALL）が、右カラムを閉じる点を含む。

#### Scenario: Second activation closes search and right column
- **WHEN** 検索ボックスが表示されている状態で再度Ctrl+F（またはCmd+F）を押す
- **THEN** 検索ボックスが非表示になり、検索クエリと結果がクリアされ、右カラムも閉じられる

#### Scenario: Toggle reopens after closing
- **WHEN** 検索ショートカットで検索を閉じた後、再度テキスト未選択で検索ショートカットを押す
- **THEN** 右カラムと検索ボックスが再び表示され、入力フィールドにフォーカスが当たる
