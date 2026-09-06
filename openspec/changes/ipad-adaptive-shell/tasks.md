## 1. レイアウト判定モデル

- [ ] 1.1 `resolveShellLayout(width:breakpoint:)` の純粋関数テストを書く（しきい値未満はnarrow、同値はwide、超過はwide、`Platform` を読まない）— RED
- [ ] 1.2 `lib/shared/layout/shell_layout.dart` に `ShellLayout` と純粋関数を実装 — GREEN
- [ ] 1.3 `shellBreakpointProvider`（既定 800）のテストを書き、既定値が `kMinimumWindowSize.width` と一致することを固定する — RED
- [ ] 1.4 `lib/shared/providers/layout_providers.dart` にしきい値 provider を追加 — GREEN

## 2. narrow レイアウトの骨格

- [ ] 2.1 しきい値 provider を 900 に上書きしたとき、body に `left_column` / `right_column` / `VerticalDivider` が存在せず `center_column` だけが残るテストを書く — RED
- [ ] 2.2 同条件で `Drawer` を開くと `left_column` が 250pt 幅で現れるテストを書く — RED
- [ ] 2.3 `HomeScreen.build` で `MediaQuery.sizeOf(context).width` としきい値から `ShellLayout` を求め、narrow では `drawer` に左カラムを、wide では従来の `Row` を組む — GREEN
- [ ] 2.4 wide（既定ビューポート 800pt）で従来どおり 3 カラムが組まれ、`Scaffold` が `drawer` を持たないことを既存テストと新規テストで確認 — GREEN
- [ ] 2.5 実ビューポートを 744pt に縮めても narrow になることを、`tester.view.physicalSize` を使ったテスト 1 本で裏取りする（しきい値上書きに依存しない担保）

## 3. エッジドラッグの無効化

- [ ] 3.1 narrow で画面左端／右端からの水平ドラッグが Drawer を開かないテストを書く — RED
- [ ] 3.2 `drawerEnableOpenDragGesture: false` / `endDrawerEnableOpenDragGesture: false` を指定 — GREEN
- [ ] 3.3 AppBar のボタンからは Drawer が開くことをテストで確認

## 4. 右カラムの endDrawer 化と provider 同期

- [ ] 4.1 narrow で `rightColumnVisibleProvider` を true にすると endDrawer が開き `right_column` が現れるテストを書く — RED
- [ ] 4.2 スクリムをタップして endDrawer を閉じると provider が false に戻るテストを書く — RED
- [ ] 4.3 `GlobalKey<ScaffoldState>` と `ref.listen` で provider → endDrawer を駆動し、`onEndDrawerChanged` で書き戻す — GREEN
- [ ] 4.4 ⌘F / 選択検索 / Escape の 3 経路が narrow でも endDrawer を開閉できることをテストで確認

## 5. Drawer の自動クローズ

- [ ] 5.1 narrow で Drawer を開いた状態からファイルを選ぶと Drawer が閉じるテストを書く — RED
- [ ] 5.2 `selectedFileProvider` を `ref.listen` して Drawer を閉じる — GREEN
- [ ] 5.3 narrow から wide へ切り替わったとき、開いていた Drawer / endDrawer が閉じるテストを書く — RED
- [ ] 5.4 レイアウト切り替えの検出とクローズ処理を実装 — GREEN

## 6. AppBar の構成

- [ ] 6.1 AppBar の検索ボタンが wide / narrow の双方に存在し、押下で `_onSearchShortcut` と同じ結果になるテストを書く — RED
- [ ] 6.2 検索ボタンを AppBar に追加し、ツールチップの ARB キーを ja / en に追加 — GREEN
- [ ] 6.3 narrow では `toggle_right_column_button` が存在せず、wide では存在するテストを書く — RED
- [ ] 6.4 カラム切替ボタンを wide 限定にする — GREEN

## 7. switchPane と初期フォーカス

- [ ] 7.1 narrow でショートカットマップに `switchPane` のエントリが含まれないテストを書く（変更 C の TTS トグルと同じ fall-through プローブ方式で、キーが他のハンドラに通ることまで確認）— RED
- [ ] 7.2 wide では従来どおり登録されることをテストで確認
- [ ] 7.3 narrow で `switchPane` を登録しないよう `shortcuts` の構築を変更 — GREEN
- [ ] 7.4 narrow では起動時の `_fileBrowserPaneFocus.requestFocus()` を行わないよう post-frame コールバックを変更 — GREEN

## 8. 解析履歴タブの capability ゲート

- [ ] 8.1 `llmSummarySupportedProvider` を false に上書きすると左カラムのタブが「ファイル」「ブックマーク」の 2 つになり、両者が従来どおり切り替わるテストを書く — RED
- [ ] 8.2 true のとき 3 タブのままであることをテストで確認（既存テストの維持）
- [ ] 8.3 `LeftColumnPanel` を `ConsumerStatefulWidget` にし、`initState` で `ref.read` して `TabController` の長さを決める — GREEN

## 9. ドキュメント

- [ ] 9.1 README の iPad ビルドの節に、狭い画面では左カラムと検索結果が Drawer になること、Drawer は AppBar のボタンからのみ開くこと（縦書きのページ送りを守るため）を追記

## 10. 実機確認（iPad mini A17 Pro）

- [ ] 10.1 縦向きで本文が画面幅いっぱいを使い、≡ から左カラムを開けること
- [ ] 10.2 ファイルを選ぶと Drawer が閉じ、本文が表示されること
- [ ] 10.3 🔍 から検索でき、結果パネルが endDrawer として開くこと。スクリムで閉じたあと再度開けること
- [ ] 10.4 縦書きで画面の左右端からの水平スワイプがページ送りとして働くこと（Drawer に奪われないこと）
- [ ] 10.5 縦向き ⇄ 横向きの回転で narrow ⇄ wide が切り替わり、Drawer が開いたまま取り残されないこと
- [ ] 10.6 左カラムのタブが「ファイル」「ブックマーク」の 2 つであること
- [ ] 10.7 AppBar のボタンが 744pt に収まり、タイトルが読めること

## 11. 最終確認

- [ ] 11.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 11.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 11.3 `fvm dart format .`でフォーマットを実行
- [ ] 11.4 `fvm flutter analyze`でリントを実行
- [ ] 11.5 `fvm flutter test`でテストを実行
