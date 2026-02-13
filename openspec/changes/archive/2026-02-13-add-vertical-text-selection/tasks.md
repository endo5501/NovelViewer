## 1. 座標→文字インデックス変換ロジック

- [x] 1.1 ポインタ座標から文字インデックスを算出する `hitTestCharIndex` 関数のテストを作成（列インデックス・行インデックスの計算、RTL方向、範囲外座標の処理を検証）
- [x] 1.2 `hitTestCharIndex` 関数を `VerticalTextPage` に実装（レイアウト定数 `fontSize`, `_kRunSpacing`, `_kTextHeight` を使用して `columnIndex`, `rowIndex` → `charIndex` を算出）
- [x] 1.3 テストを実行し、全テストがパスすることを確認してコミット

## 2. 選択テキスト抽出ロジック

- [x] 2.1 `_CharEntry` リストから選択範囲のテキストを抽出する `extractVerticalSelectedText` 関数のテストを作成（PlainText の原文取得、RubyText のベーステキスト取得、改行の処理、範囲外インデックスの処理を検証）
- [x] 2.2 `extractVerticalSelectedText` 関数を実装（`_CharEntry.text` から原文を取得、ルビはベーステキストを返却）
- [x] 2.3 テストを実行し、全テストがパスすることを確認してコミット

## 3. 選択状態管理とハイライト描画

- [x] 3.1 `VerticalTextPage` に選択状態（`selectionStart`, `selectionEnd`）パラメータを追加し、選択範囲の文字に青系背景色（`Colors.blue.withOpacity(0.3)`）が適用されることのテストを作成
- [x] 3.2 `_buildCharWidget` と `_createTextStyle` を拡張して選択ハイライトを描画。検索ハイライト（黄色）が選択ハイライト（青）より優先されるロジックを実装
- [x] 3.3 テストを実行し、全テストがパスすることを確認してコミット

## 4. GestureDetector によるドラッグ選択

- [x] 4.1 `VerticalTextPage` に `GestureDetector` を追加し、`onPanStart`/`onPanUpdate`/`onPanEnd` でドラッグ選択を処理するテストを作成（ドラッグで選択範囲が更新されること、タップで選択がクリアされることを検証）
- [x] 4.2 `VerticalTextPage` を `StatefulWidget` に変更し、`GestureDetector` を `Wrap` の親に配置。ドラッグイベントで `hitTestCharIndex` を呼び出して選択範囲を更新。`onSelectionChanged` コールバックで選択テキストを通知
- [x] 4.3 テストを実行し、全テストがパスすることを確認してコミット

## 5. VerticalTextViewer との統合

- [x] 5.1 `VerticalTextViewer` が `VerticalTextPage` の `onSelectionChanged` コールバックを受け取り、選択テキストを上位に通知するテストを作成
- [x] 5.2 `VerticalTextViewer` に `onSelectionChanged` コールバックを追加。ページ遷移時（`_nextPage`, `_previousPage`）に選択をクリアするロジックを実装
- [x] 5.3 テストを実行し、全テストがパスすることを確認してコミット

## 6. TextViewerPanel との統合

- [x] 6.1 `TextViewerPanel` が縦書きモードの `VerticalTextViewer` から選択テキストを受け取り `selectedTextProvider` に反映するテストを作成
- [x] 6.2 `TextViewerPanel` の縦書きモード部分に `onSelectionChanged` コールバックを接続し、`selectedTextProvider` を更新する実装
- [x] 6.3 テストを実行し、全テストがパスすることを確認してコミット

## 7. 最終確認

- [x] 7.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [x] 7.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 7.3 `fvm flutter analyze`でリントを実行
- [x] 7.4 `fvm flutter test`でテストを実行
