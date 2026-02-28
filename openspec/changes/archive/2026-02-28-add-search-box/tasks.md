## 1. 状態管理の追加

- [x] 1.1 `searchBoxVisibleProvider`（`NotifierProvider<bool>`）を`text_search_providers.dart`に追加する
- [x] 1.2 `searchBoxVisibleProvider`の単体テストを作成する（初期値false、show/hide切り替え）

## 2. キーボードショートカットの動作分岐

- [x] 2.1 `home_screen.dart`の`_SearchIntent`ハンドラを変更し、テキスト未選択時に`searchBoxVisibleProvider`をtrueにセットし、右カラムを自動表示するロジックを追加する
- [x] 2.2 テキスト選択あり時の既存動作（即時検索）が維持されていることを確認するテストを作成する
- [x] 2.3 テキスト未選択時にCtrl+Fを押すと`searchBoxVisibleProvider`がtrueになることを確認するテストを作成する

## 3. 検索ボックスUIの実装

- [x] 3.1 `SearchResultsPanel`の上部にTextFieldを追加し、`searchBoxVisibleProvider`がtrueの場合にのみ表示する
- [x] 3.2 検索ボックス表示時にTextFieldにフォーカスを自動的に当てる（FocusNodeの管理）
- [x] 3.3 TextFieldの`onSubmitted`で入力テキストを`searchQueryProvider`にセットし検索を実行する
- [x] 3.4 空文字列でEnterを押した場合、検索クエリをクリアする処理を実装する
- [x] 3.5 検索ボックスUIの表示/非表示テストを作成する
- [x] 3.6 検索ボックスからの検索実行テスト（onSubmittedでsearchQueryProviderが更新される）を作成する

## 4. Escキーによる検索ボックスの閉じる動作

- [x] 4.1 検索ボックスにフォーカス中のEscキーでsearchBoxVisibleProviderをfalseにし、searchQueryProviderをクリアする処理を実装する
- [x] 4.2 Escキーで検索ボックスが閉じることを確認するテストを作成する

## 5. 最終確認

- [x] 5.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [x] 5.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 5.3 `fvm flutter analyze`でリントを実行
- [x] 5.4 `fvm flutter test`でテストを実行
