## Why

検索 UI のリファクタリングで LLM 解析 UI がポップアップメニューへ移動した結果、右カラム (SearchResultsPanel) は「検索ボックス + 検索結果」のみを表示する領域になった。これに伴い、以下 2 件の UX 不具合が顕在化している。

1. アプリ起動直後に空の検索結果領域が常に表示される (以前は LLM 解析の起点としても機能していたが現在は空のため、画面占有のみで価値がない)。
2. 検索を Esc やクリアで終了しても、オレンジ色の検索ハイライトがテキスト上に残り続ける。

これらは検索機能の使用感を直接損なうため、修正する。

## What Changes

- 右カラムの起動時表示デフォルトを「表示」から「非表示」に変更する。
- AppBar の右カラムトグルボタンは維持し、ユーザーが手動で開閉できる選択肢を残す。
- 既存の Ctrl+F (テキスト未選択時) 時に右カラムを自動表示するロジックは維持する。
- 検索終了 (Esc) または検索クエリのクリア (`searchQuery = null`) 時に、検索ハイライト (`selectedSearchMatch`) も併せてクリアする。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `column-visibility-toggle`: 右カラムの起動時デフォルト状態を「表示」から「非表示」に変更する。トグルボタンによる手動開閉は維持。
- `text-search`: 検索終了時およびクエリクリア時にハイライトもクリアされる要件を追加する。

## Impact

- `lib/shared/providers/layout_providers.dart`: `RightColumnVisibleNotifier.build()` のデフォルト戻り値を `true` から `false` に変更。
- `lib/home_screen.dart`: `_handleEscapeKey` で `selectedSearchMatchProvider.clear()` を追加。
- `lib/features/text_search/presentation/search_results_panel.dart`: `_onEscape` で `selectedSearchMatchProvider.clear()` を追加。
- 既存テスト更新が必要: `test/shared/providers/layout_providers_test.dart` (デフォルト値変更)、`test/home_screen_test.dart` (起動時の右カラム表示前提を変更)。
