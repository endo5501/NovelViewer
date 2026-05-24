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
- [x] 3.4 ここまでをコミットした (`4e7d651 fix: pass ruby-base-expanded text to horizontal context menu actions`)。

## 4. 副次効果の確認

- [x] 4.1 `Grep "buildDictionaryContextMenu"` の結果、`lib/` 配下の呼び出し元は `text_content_renderer.dart`（横書き本文） と `tts_edit_dialog.dart`（TTS編集ダイアログのプレーンテキスト編集）の2か所であることを確認。後者は元から U+FFFC 影響を受けない（ルビなしの TextField）ため、明示的な `selection.textInside(value.text)` 引き渡しで等価維持。
- [x] 4.2 `Grep "analysisRunnerProvider\|_runAnalysis"` の結果、`analysisRunnerProvider` は `analysis_runner.dart` で定義、`text_content_renderer.dart` の `_runAnalysis` 経由でのみ呼ばれる。hover popup 経路 (`hoverPopupProvider` / `hover_popup_widget`) は別系統で `_runAnalysis` を通らないため本修正の影響なし。
- [ ] 4.3 横書きで実際にルビ付きの小説を開き、ルビを含む選択 → 「解析開始(ネタバレなし)」「解析開始(ネタバレあり)」「辞書追加」をそれぞれ試して期待通り動作することを目視確認する。**ユーザー側での手動確認をお願いします（Flutter Windows デスクトップ GUI のため）**。

## 5. 最終確認

- [x] 5.1 code-review スキルを実施 (5 angles × 8 candidates → verify → 4 finding)。所見:
  - **C2 CONFIRMED**: 横書きのシステム「コピー」も U+FFFC を吐く（base items が `editableTextState.contextMenuButtonItems` のまま転送されており、`onPressed` が `EditableText.copySelection` 経由で `value.text` を読むため）→ §6 で追加修正。
  - **C1 CONFIRMED**: `selectedTextFromSelection` 内の `min/max` 冗長（Flutter `TextSelection.start/.end` は SDK 側で `baseOffset`/`extentOffset` の min/max に正規化済み）→ §6 で追加修正。
  - C3/C4 PLAUSIBLE: レイヤリング (data 層 → Flutter 依存) と clamp 欠如 (理論上の edge case)。本 PR では非対応で follow-up 対象。
- [x] 5.2 codex スキル (`codex:rescue` → `codex:codex-rescue` GPT-5.4) でセカンドオピニオン取得。CRITICAL/MAJOR なし。MINOR 3 件すべて既知の follow-up（境界外クランプ欠如 / `AdaptiveTextSelectionToolbar` への `as` キャスト脆さ / テストの l10n ラベルハードコード）でマージ可と判断。
- [x] 5.3 `fvm flutter analyze` 実行 → 本 PR 由来の警告ゼロ（`prefer_const_declarations` を §6 で修正済）。
- [x] 5.4 `fvm flutter test` 実行 → 全 1567 件 pass。

## 6. code-review 由来の追加修正

- [x] 6.1 (Red) `dictionary_context_menu_test.dart` に Copy 項目リマップの testWidgets を追加。`SystemChannels.platform` を mock して `Clipboard.setData` に渡る text を捕捉。base の Copy onPressed は呼ばれないこと、非 Copy 項目（Paste/SelectAll）は元のまま、も併せて検証 (2 ケース追加)。
- [x] 6.2 (Green) `buildAnalysisButtonItems` で `baseItems` を `map` し、`type == ContextMenuButtonType.copy` を `Clipboard.setData(ClipboardData(text: selectedText))` を呼ぶ新 `ContextMenuButtonItem` に差し替えた。selectedText 空の場合はスルー（元の Copy 挙動 = 空文字列コピー）を維持。
- [x] 6.3 (C1) `selectedTextFromSelection` から `min/max` を削除、`dart:math` import も削除。テスト「reversed selections」のコメントを「TextSelection は SDK 側で start/end が正規化済み」と説明する形に更新。
- [x] 6.4 `fvm flutter test` 全 1567 件 Green、`fvm flutter analyze` 本 PR 由来の警告ゼロ (既存 `voice_recording_service_test.dart` の `override_on_non_overriding_member` 1 件のみ残るが本 PR と無関係)。
- [x] 6.5 ここまでをコミットした (`9a25e0c fix: rewrite Copy item to use ruby-base text; drop redundant min/max`)。
