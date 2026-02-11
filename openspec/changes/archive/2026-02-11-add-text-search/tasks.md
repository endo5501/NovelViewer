## 1. 検索データモデルとサービス

- [x] 1.1 `SearchMatch`クラス（行番号、コンテキストテキスト）と`SearchResult`クラス（ファイル名、ファイルパス、マッチリスト）のテストを作成
- [x] 1.2 `SearchMatch`と`SearchResult`のデータモデルを`lib/features/text_search/data/`に実装
- [x] 1.3 `TextSearchService`のテストを作成（複数ファイルでのマッチ、マッチなし、大文字小文字区別なし、コンテキスト抽出）
- [x] 1.4 `TextSearchService`を`lib/features/text_search/data/text_search_service.dart`に実装

## 2. 検索状態管理（Providers）

- [x] 2.1 `selectedTextProvider`のテストを作成（テキスト選択の追跡、クリア）
- [x] 2.2 `selectedTextProvider`を`lib/features/text_viewer/providers/text_viewer_providers.dart`に追加
- [x] 2.3 `searchQueryProvider`と`searchResultsProvider`のテストを作成（検索実行、ディレクトリ変更時の再検索、クエリクリア時の結果クリア）
- [x] 2.4 `searchQueryProvider`と`searchResultsProvider`を`lib/features/text_search/providers/text_search_providers.dart`に実装

## 3. テキストビューアの選択追跡とショートカット

- [x] 3.1 `TextViewerPanel`のテキスト選択追跡のテストを作成（`onSelectionChanged`で`selectedTextProvider`が更新されること）
- [x] 3.2 `TextViewerPanel`に`onSelectionChanged`コールバックを追加し`selectedTextProvider`を更新する実装
- [x] 3.3 Cmd+F / Ctrl+Fキーボードショートカットのテストを作成（選択テキストがある場合に`searchQueryProvider`が設定されること、選択テキストがない場合は何もしないこと）
- [x] 3.4 `HomeScreen`に`Shortcuts` + `Actions`ウィジェットでCmd+F / Ctrl+Fショートカットを実装

## 4. 右辺カラムのレイアウト変更

- [x] 4.1 `SearchSummaryPanel`の2段構成レイアウトのテストを作成（上段LLM要約プレースホルダー、下段検索結果エリア、Divider分割）
- [x] 4.2 `SearchSummaryPanel`を上段・下段の2段構成に変更

## 5. 検索結果表示パネル

- [x] 5.1 検索結果パネルのテストを作成（ファイル別グループ表示、行番号・コンテキスト表示、ローディング状態、結果なし状態、初期プレースホルダー状態）
- [x] 5.2 検索結果パネルを`lib/features/text_search/presentation/search_results_panel.dart`に実装
- [x] 5.3 検索結果のファイル名クリックでファイル遷移するテストを作成（`selectedFileProvider`が更新されること）
- [x] 5.4 検索結果のファイル名タップで`selectedFileProvider`を更新するナビゲーション機能を実装

## 6. 最終確認

- [x] 6.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [x] 6.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 6.3 `fvm flutter analyze`でリントを実行
- [x] 6.4 `fvm flutter test`でテストを実行
