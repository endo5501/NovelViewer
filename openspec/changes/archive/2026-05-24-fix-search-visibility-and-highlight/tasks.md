## 1. 右カラム初期非表示の実装

- [x] 1.1 `test/shared/providers/layout_providers_test.dart` を更新し、`rightColumnVisibleProvider` のデフォルトが `false` になることを検証するテストへ修正 (失敗を確認)
- [x] 1.2 `lib/shared/providers/layout_providers.dart` の `RightColumnVisibleNotifier.build()` を `false` を返すよう変更し、テストを通す
- [x] 1.3 `test/home_screen_test.dart` の起動時挙動テストを「起動直後は `right_column` が表示されない」前提に修正
- [x] 1.4 `test/home_screen_test.dart` に Ctrl+F 押下で右カラムが表示されることを確認するテストを追加 (既存があれば確認のみ)
- [x] 1.5 `test/home_screen_test.dart` に AppBar の `toggle_right_column_button` クリックで右カラムを手動表示できることを確認するテストを追加 (既存があれば確認のみ)

## 2. ハイライトクリアの実装

- [x] 2.1 `searchQueryProvider.notifier).setQuery(null)` を呼び出している箇所を grep でリスト化 (Esc 以外の経路の有無を確認)
- [x] 2.2 `test/home_screen_test.dart` に「検索ハイライト表示中に Esc を押すと `selectedSearchMatchProvider` がクリアされる」テストを追加 (失敗を確認)
- [x] 2.3 `test/features/text_search/presentation/search_results_panel_test.dart` に「検索ボックスにフォーカスがある状態で Esc を押すと `selectedSearchMatchProvider` がクリアされる」テストを追加 (失敗を確認)
- [x] 2.4 `lib/home_screen.dart` の `_handleEscapeKey` で `ref.read(selectedSearchMatchProvider.notifier).clear()` を追加し、テストを通す
- [x] 2.5 `lib/features/text_search/presentation/search_results_panel.dart` の `_onEscape` で `ref.read(selectedSearchMatchProvider.notifier).clear()` を追加し、テストを通す
- [x] 2.6 2.1 で発見した他の `setQuery(null)` 呼び出し箇所があれば、必要に応じて `selectedSearchMatchProvider.clear()` を追加
- [x] 2.7 (code-review 追加) 新しい query 設定時にも stale な `selectedSearchMatch` をクリアする RED テストを追加 (`_onSubmitted` 非空分岐、`_SearchIntent` selected text 分岐の 2 箇所)
- [x] 2.8 (code-review 追加) `_onSubmitted` と `_SearchIntent` の selected text 分岐に `clear()` を追加し GREEN

## 3. 最終確認

- [x] 3.1 code-review スキルを使用してコードレビューを実施 (2 件の追加バグを発見 → 2.7/2.8 で対応済)
- [x] 3.2 codex スキルを使用して現在開発中のコードレビューを実施 (clear/setQuery 順序統一の改善提案を反映)
- [x] 3.3 `fvm flutter analyze` でリントを実行
- [x] 3.4 `fvm flutter test` でテストを実行
