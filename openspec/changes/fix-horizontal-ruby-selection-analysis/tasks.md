## 1. 既存挙動の固定（回帰防止）

- [x] 1.1 `test/features/text_viewer/ruby_text_parser_test.dart` を確認し、`extractSelectedText(start, end, segments)` がルビ単体選択・ルビをまたぐ選択・プレーン選択の3パターンで期待通りの base 抽出を返すテストが既に存在することを確認した（`group('extractSelectedText', ...)` 内）。追加不要。

## 2. TDD: 失敗テストを先に追加する

- [x] 2.1 `test/features/tts/presentation/dictionary_context_menu_test.dart` に `buildDictionaryContextMenu` の新シグネチャ（`required String selectedText`）を前提とした widget test を追加した。`EditableTextState.textEditingValue.text` が U+FFFC でも、明示的に渡した `selectedText="宇宙"` が onAnalyze / onAddToDictionary に届くことを検証する3ケースを追加。
- [x] 2.2 `test/features/text_viewer/ruby_text_parser_test.dart` に新ヘルパー `selectedTextFromSelection(TextSelection, List<TextSegment>)` のテストを追加した。invalid / collapsed / ルビ単体 / ルビ越境 / 逆向き選択 / プレーン / U+FFFC 含まれない保証 の7ケース。
- [x] 2.3 `fvm flutter test` を実行し、両ファイルが期待通り Red（コンパイルエラー）になることを確認した。
- [x] 2.4 ここまでをコミットした (`1382346 test: add failing tests for horizontal ruby selection analysis`)。

## 3. 実装（Green）

- [x] 3.1 `lib/features/tts/presentation/dictionary_context_menu.dart` の `buildDictionaryContextMenu` を新シグネチャ（`required String selectedText`）に変更し、内部の `selection.textInside(value.text)` 抽出を削除した。
- [x] 3.2 `lib/features/text_viewer/presentation/widgets/text_content_renderer.dart` の `contextMenuBuilder` を、新ヘルパー `selectedTextFromSelection(selection, segments)` の戻り値を `selectedText:` に渡すよう更新した。`onSelectionChanged` 側も同じヘルパーを使うようリファクタし、`dart:math` の `min/max` import を削除した。新ヘルパー `selectedTextFromSelection` は `lib/features/text_viewer/data/ruby_text_parser.dart` に追加（既存の `extractSelectedText` の薄いラッパー）。
- [x] 3.2b 巻き添えで `lib/features/tts/presentation/tts_edit_dialog.dart` の呼び出し元（TTS編集ダイアログの TextField、ルビなしのプレーンテキスト）も新シグネチャに更新した（`selection.textInside(value.text)` を明示的に算出して渡す）。
- [x] 3.3 `fvm flutter test` を実行し、新規 dictionary_context_menu / ruby_text_parser テストがGreen化し、全 1565 件がパスすることを確認した（回帰なし）。
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
