## 1. 状態管理の実装

- [x] 1.1 右カラム表示状態を管理する `NotifierProvider<bool>` を作成（デフォルト値: true）
- [x] 1.2 Provider のユニットテストを作成（初期値が true であることを確認）

## 2. トグルボタンの実装

- [x] 2.1 AppBar の actions にトグルボタン（IconButton）を追加（ダウンロードボタンの前に配置）
- [x] 2.2 右カラム表示時は `Icons.vertical_split`、非表示時は `Icons.view_sidebar` を表示するようにする
- [x] 2.3 ボタンクリックで NotifierProvider の値を反転させる処理を実装
- [x] 2.4 トグルボタンのウィジェットテストを作成（アイコン切り替え、クリック動作）

## 3. レイアウトの条件付きレンダリング

- [x] 3.1 `HomeScreen` の `body` の `Row` から `const` 修飾を削除
- [x] 3.2 右カラム（`SearchSummaryPanel`）と左側の `VerticalDivider` を NotifierProvider の値に応じて条件付き表示にする
- [x] 3.3 右カラム非表示時に中央カラムが全幅に拡張されることを確認するウィジェットテストを作成

## 4. 最終確認

- [x] 4.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [x] 4.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 4.3 `fvm flutter analyze`でリントを実行
- [x] 4.4 `fvm flutter test`でテストを実行
