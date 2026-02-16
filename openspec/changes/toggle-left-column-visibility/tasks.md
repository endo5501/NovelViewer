## 1. 状態管理の実装

- [ ] 1.1 右カラム表示状態を管理する `StateProvider<bool>` を作成（デフォルト値: true）
- [ ] 1.2 Provider のユニットテストを作成（初期値が true であることを確認）

## 2. トグルボタンの実装

- [ ] 2.1 AppBar の actions にトグルボタン（IconButton）を追加（ダウンロードボタンの前に配置）
- [ ] 2.2 右カラム表示時は `Icons.vertical_split`、非表示時は `Icons.view_sidebar` を表示するようにする
- [ ] 2.3 ボタンクリックで StateProvider の値を反転させる処理を実装
- [ ] 2.4 トグルボタンのウィジェットテストを作成（アイコン切り替え、クリック動作）

## 3. レイアウトの条件付きレンダリング

- [ ] 3.1 `HomeScreen` の `body` の `Row` から `const` 修飾を削除
- [ ] 3.2 右カラム（`SearchSummaryPanel`）と左側の `VerticalDivider` を StateProvider の値に応じて条件付き表示にする
- [ ] 3.3 右カラム非表示時に中央カラムが全幅に拡張されることを確認するウィジェットテストを作成

## 4. 最終確認

- [ ] 4.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [ ] 4.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 4.3 `fvm flutter analyze`でリントを実行
- [ ] 4.4 `fvm flutter test`でテストを実行
