## 1. 既存挙動の固定（回帰防止）

- [x] 1.1 `test/features/text_viewer/ruby_text_parser_test.dart` を確認し、`extractSelectedText(start, end, segments)` がルビ単体選択・ルビをまたぐ選択・プレーン選択の3パターンで期待通りの base 抽出を返すテストが既に存在することを確認した（`group('extractSelectedText', ...)` 内）。追加不要。

## 2. TDD: 失敗テストを先に追加する

- [x] 2.1 `test/features/tts/presentation/dictionary_context_menu_test.dart` に `buildDictionaryContextMenu` の新シグネチャ（`required String selectedText`）を前提とした widget test を追加した。`EditableTextState.textEditingValue.text` が U+FFFC でも、明示的に渡した `selectedText="宇宙"` が onAnalyze / onAddToDictionary に届くことを検証する3ケースを追加。
- [x] 2.2 `test/features/text_viewer/ruby_text_parser_test.dart` に新ヘルパー `selectedTextFromSelection(TextSelection, List<TextSegment>)` のテストを追加した。invalid / collapsed / ルビ単体 / ルビ越境 / 逆向き選択 / プレーン / U+FFFC 含まれない保証 の7ケース。
- [x] 2.3 `fvm flutter test` を実行し、両ファイルが期待通り Red（コンパイルエラー）になることを確認した。
- [ ] 2.4 ここまでをコミットする（テストのみ）。コミットメッセージ例: `test: add failing tests for horizontal ruby selection analysis`

## 3. 実装（Green）

- [ ] 3.1 `lib/features/tts/presentation/dictionary_context_menu.dart` の `buildDictionaryContextMenu` を以下のようにリファクタする:
   - シグネチャに `required String selectedText` を追加する
   - 内部の `final selectedText = selection.isValid && !selection.isCollapsed ? selection.textInside(value.text) : '';` を削除する（引数を直接使う）
   - `editableTextState.contextMenuButtonItems` と `editableTextState.contextMenuAnchors` は引き続き使う
- [ ] 3.2 `lib/features/text_viewer/presentation/widgets/text_content_renderer.dart` の `contextMenuBuilder` を更新する:
   - クロージャ内で `editableTextState.textEditingValue.selection` から start/end を取得する（`min`/`max` で正規化、`isValid && !isCollapsed` チェック付き）
   - `extractSelectedText(start, end, segments)` で正しい文字列を計算する
   - `buildDictionaryContextMenu(..., selectedText: ...)` に渡す
   - `segments` は build メソッド内のローカルだが、`contextMenuBuilder` のクロージャでキャプチャできることを確認する
- [ ] 3.3 `fvm flutter test` を実行し、2.1 / 2.2 が通ること、既存テストが回帰していないことを確認する（Green）。
- [ ] 3.4 ここまでをコミットする。コミットメッセージ例: `fix: pass ruby-base-expanded text to horizontal context menu actions`

## 4. 副次効果の確認

- [ ] 4.1 `Grep "buildDictionaryContextMenu"` で呼び出し元が `text_content_renderer.dart` の 1 か所だけであることを再確認する。
- [ ] 4.2 hover popup 経由の解析開始経路 (`hoverPopupProvider` / `analysisRunnerProvider`) がコンテキストメニューと独立しており、本修正の影響を受けないことを `Grep "analysisRunnerProvider\|_runAnalysis"` で確認する。
- [ ] 4.3 横書きで実際にルビ付きの小説（例: 青空文庫の青空・著作権切れ作品など、すでに開発環境に存在するサンプル）を開き、ルビを含む選択 → 「解析開始(ネタバレなし)」「解析開始(ネタバレあり)」「辞書追加」をそれぞれ試して期待通り動作することを目視確認する。verify スキルや手動実行で OK。

## 5. 最終確認

- [ ] 5.1 code-review スキルを使用してコードレビューを実施
- [ ] 5.2 codex スキルを使用して現在開発中のコードレビューを実施
- [ ] 5.3 `fvm flutter analyze` でリントを実行
- [ ] 5.4 `fvm flutter test` でテストを実行
