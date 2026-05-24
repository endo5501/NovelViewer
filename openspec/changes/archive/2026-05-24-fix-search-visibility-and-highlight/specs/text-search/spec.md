## ADDED Requirements

### Requirement: Search highlight lifecycle
検索ハイライト (`selectedSearchMatch`) は、検索を終了した時点 (Esc キーによる検索終了) または検索クエリをクリアした時点 (`searchQuery` が `null` に設定された時点) に併せてクリアされなければならない（SHALL）。ハイライトが残留してテキストビューア上に表示され続けることがあってはならない（SHALL NOT）。

#### Scenario: Highlight clears when search is dismissed via Escape from search box
- **WHEN** ユーザーが検索ボックスにフォーカスがある状態で Esc キーを押す
- **THEN** 検索ボックスが非表示になり、`searchQuery` が `null` にクリアされる
- **AND** `selectedSearchMatch` も併せて `null` にクリアされ、テキストビューア上のハイライト (オレンジ/イエロー/アンバー背景) が消去される

#### Scenario: Highlight clears when search is dismissed via global Escape handler
- **WHEN** ユーザーが検索ボックス以外にフォーカスがある状態で、検索状態 (検索ボックス表示中 または `searchQuery` 非 null) で Esc キーを押す
- **THEN** `searchBoxVisible` が `false`、`searchQuery` が `null` に設定される
- **AND** `selectedSearchMatch` も併せて `null` にクリアされ、テキストビューア上のハイライトが消去される

#### Scenario: Highlight remains while query and selected match are both active
- **WHEN** ユーザーが検索を実行し、検索結果リストの特定のマッチをクリックして `selectedSearchMatch` が設定された状態
- **THEN** `searchQuery` または `selectedSearchMatch` がクリアされるまでハイライトは保持される
