## MODIFIED Requirements

### Requirement: Search highlight lifecycle
検索ハイライト (`selectedSearchMatch`) は、検索を終了した時点 (Esc キーによる検索終了) または検索クエリをクリアした時点 (`searchQuery` が `null` に設定された時点) に併せてクリアされなければならない（SHALL）。ハイライトが残留してテキストビューア上に表示され続けることがあってはならない（SHALL NOT）。

グローバル Esc ハンドラによる検索終了は、ファイルブラウザの `Drawer` が開いていない状態に限る。ファイルブラウザの `Drawer` が開いている間、Esc は手前にあるその `Drawer` を閉じることに費やされ、検索セッションには影響しない。検索を終了するには、`Drawer` が閉じた後にもう一度 Esc を押す。

検索結果を収めた `endDrawer` はこの限定の対象外である。`endDrawer` の dismiss は検索セッションの終了そのものであり、Esc による検索終了とそれに伴う `endDrawer` の閉鎖は従来どおり一度の押下で完結する。

#### Scenario: Highlight clears when search is dismissed via Escape from search box
- **WHEN** ユーザーが検索ボックスにフォーカスがある状態で Esc キーを押す
- **THEN** 検索ボックスが非表示になり、`searchQuery` が `null` にクリアされる
- **AND** `selectedSearchMatch` も併せて `null` にクリアされ、テキストビューア上のハイライト (オレンジ/イエロー/アンバー背景) が消去される

#### Scenario: Highlight clears when search is dismissed via global Escape handler
- **WHEN** ユーザーが検索ボックス以外にフォーカスがあり、ファイルブラウザの `Drawer` が開いていない状態で、検索状態 (検索ボックス表示中 または `searchQuery` 非 null) で Esc キーを押す
- **THEN** `searchBoxVisible` が `false`、`searchQuery` が `null` に設定される
- **AND** `selectedSearchMatch` も併せて `null` にクリアされ、テキストビューア上のハイライトが消去される

#### Scenario: Escape while a drawer is open leaves the search untouched
- **WHEN** 検索状態でファイルブラウザの `Drawer` が開いている状態で Esc キーを押す
- **THEN** `Drawer` のみが閉じ、`searchBoxVisible`・`searchQuery`・`selectedSearchMatch` はいずれも変化せず、ハイライトも保持される
- **AND** 続けてもう一度 Esc キーを押すと、通常どおり検索が終了しハイライトが消去される

#### Scenario: Highlight remains while query and selected match are both active
- **WHEN** ユーザーが検索を実行し、検索結果リストの特定のマッチをクリックして `selectedSearchMatch` が設定された状態
- **THEN** `searchQuery` または `selectedSearchMatch` がクリアされるまでハイライトは保持される
