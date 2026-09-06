## ADDED Requirements

### Requirement: AppBarからの検索起動
アプリケーションはAppBarに検索ボタンを表示しなければならない（SHALL）。このボタンは検索ショートカット（Ctrl+F/Cmd+F）と同一の処理を呼び出さなければならない（SHALL）——テキスト未選択なら検索ボックスを開き、テキスト選択中ならその選択で即時検索し、検索が既に開いていれば検索セッションを閉じる。キーボードを接続していないタブレットには検索ショートカットという入口が存在しないため、このボタンはレイアウトに関わらず常に表示されなければならない（SHALL）。

#### Scenario: ボタンから検索ボックスを開く
- **WHEN** テキストを選択していない状態でAppBarの検索ボタンを押す
- **THEN** 検索ボックスが表示され、テキスト入力フィールドにフォーカスが当たる（ショートカットを押した場合と同じ結果になる）

#### Scenario: ボタンで検索セッションを閉じる
- **WHEN** wideレイアウトで検索ボックスが表示されている状態でAppBarの検索ボタンを押す
- **THEN** 検索ボックスが非表示になり、検索クエリと結果がクリアされ、右カラムも閉じられる

#### Scenario: narrowレイアウトではDrawer自身の操作で閉じる
- **WHEN** narrowレイアウトでendDrawerが開いている
- **THEN** endDrawerがAppBarの右側を覆うため検索ボタンは押下できず、スクリムのタップ・戻る操作・検索ショートカット・Escapeで閉じられる

#### Scenario: 検索ボタンは両レイアウトで存在する
- **WHEN** wideレイアウトとnarrowレイアウトのそれぞれでAppBarを確認する
- **THEN** いずれの場合も検索ボタンが存在する

## MODIFIED Requirements

### Requirement: Search box display control
検索ボックスはCtrl+F/Cmd+FまたはAppBarの検索ボタンでテキスト未選択時に表示されなければならない（SHALL）。検索ボックスが表示されると、テキスト入力フィールドに自動的にフォーカスが移動しなければならない（SHALL）。このフォーカス移動は、右カラムが直前まで非表示でSearchResultsPanelが未マウントだった場合（検索の起動により右カラムと同時に表示される場合）でも、初回表示時に確実に行われなければならない（SHALL）。narrowレイアウトでは右カラムは`endDrawer`として現れるが、フォーカスの扱いは同一でなければならない（SHALL）。

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

#### Scenario: Focus reaches the field when the right pane opens as a drawer
- **WHEN** narrowレイアウトでテキスト未選択のまま検索を起動する
- **THEN** endDrawerが開いて検索ボックスが表示され、初回表示でテキスト入力フィールドにフォーカスが当たる
