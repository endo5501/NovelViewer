## 1. 検索結果のソート

- [x] 1.1 `searchResultsProvider` でソート済みの結果を返すよう修正する。数値プレフィックスを持つファイルは数値順、持たないファイルはアルファベット順（数値プレフィックスファイルの後）にソートする
- [x] 1.2 ソートロジックのユニットテストを追加する（数値プレフィックス、非数値、混在のケース）

## 2. マッチ選択状態の管理

- [x] 2.1 `SelectedSearchMatch` モデルクラス（filePath, lineNumber, query）を `search_models.dart` に追加する
- [x] 2.2 `selectedSearchMatchProvider`（Notifier）を `text_search_providers.dart` に追加する
- [x] 2.3 `search_results_panel.dart` でマッチ行を `InkWell` でラップし、クリック時に `selectedFileProvider` と `selectedSearchMatchProvider` を同時に更新する

## 3. テキストハイライト

- [x] 3.1 `text_viewer_panel.dart` で `selectedSearchMatchProvider` を watch し、検索クエリが存在する場合に `SelectableText.rich` でテキスト内のマッチ箇所をハイライト表示する
- [x] 3.2 ハイライト用の `TextSpan` 構築ロジックのユニットテストを追加する

## 4. 行位置スクロール

- [x] 4.1 `text_viewer_panel.dart` に `ScrollController` を追加し、`selectedSearchMatchProvider` の行番号変更時にテキストスタイルの行高さを元に算出したオフセットへ `animateTo()` でスクロールする
- [x] 4.2 同一ファイル内で異なるマッチ行を選択した場合にスクロール位置が更新されることを確認するテストを追加する

## 5. 最終確認

- [x] 5.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [x] 5.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 5.3 `fvm flutter analyze`でリントを実行
- [x] 5.4 `fvm flutter test`でテストを実行
