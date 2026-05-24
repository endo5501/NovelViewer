## 1. 事前検証（spike）

- [x] 1.1 最小プロトを書いて `TextSpan.onEnter`/`onExit` が `SelectableText.rich` 配下の decoration付き TextSpan で発火することを確認する。隣接 span との境界 flicker の有無、`decoration: underline` との併存可否、`event.position` の値域も観察。失敗時は design.md R1 の代替案 (b) に切り替え判断

## 2. 既存テスト/UIの撤去

- [x] 2.1 `LlmSummaryPanel` を参照する既存 widget test の洗い出しと、本change完了後に何を残し何を消すか整理（テスト先行で削除リストを書き出す）
- [x] 2.2 `SearchSummaryPanel` を撤去する前提で、`SearchResultsPanel` を直接配置できるよう `home_screen.dart` を読み解き、変更箇所を特定
- [x] 2.3 `LlmSummaryPanel` 削除時の影響範囲スキャン（grep で参照元洗い出し）

## 3. ホバーポップアップ：domain/state層（TDD）

- [x] 3.1 ホバーポップアップの状態モデル（表示中/単語/位置/種別）を表す不変オブジェクトのテストを書く
- [x] 3.2 `HoverPopupNotifier`（`show(word, position)` / `hide()` / `setSummaryType(type)`）の状態遷移テストを書く
- [x] 3.3 上記2つの実装を追加して green 化
- [x] 3.4 ホバー対象単語のキャッシュ取得 provider（folder+word を family key とする FutureProvider）のテストを書く（noSpoiler/spoiler 両方解決、片方のみ、両方なしの3パターン）
- [x] 3.5 provider 実装を追加して green 化

## 4. ホバーポップアップ：横書きのhover検出（TDD）

- [x] 4.1 mark付き TextSpan に `onEnter/onExit` を生やすロジックのテストを書く（`MarkSpan.word` がハンドラに渡ること、複数mark並びでも正しく分配されること、未mark span にはハンドラが付かないこと）
- [x] 4.2 `_applyLocalMarksToSpans` を拡張して onEnter/onExit を受け取れるようにし、`ruby_text_builder` から hover ハンドラを渡せるよう改修して green 化
- [x] 4.3 hover 連続切り替え（語Aから語Bへマウスが移動）の挙動テスト：A.onExit → B.onEnter の順序、notifier 状態が B に切り替わること

## 5. ホバーポップアップ：widget 表示（TDD）

- [x] 5.1 ポップアップ widget 単体テスト：単一種別キャッシュ時に切替ピル非表示、両種別キャッシュ時にピル表示と既定 noSpoiler、ピル切替で表示テキスト更新
- [x] 5.2 ズレ警告テスト：noSpoiler 表示 + `sourceFile != currentFile` で警告表示、`sourceFile == currentFile` で非表示、spoiler 表示時は常に非表示
- [x] 5.3 ローディング表示テスト：cache fetch 未解決時に loading indicator、解決後に内容置換
- [x] 5.4 ポップアップ widget 実装を追加して green 化
- [x] 5.5 `TextContentRenderer` 配下にラッパ widget を追加して、`HoverPopupNotifier` 状態を `ref.listen` し OverlayEntry の挿入/破棄を行う実装を追加。横書きモードでのみ反応すること
- [x] 5.6 横書き widget test：marked TextSpan へのhover操作→Overlayにポップアップ挿入、leave操作→破棄。実マウスイベントの代わりに onEnter/onExit を直接呼ぶ形でOK

## 6. ホバーポップアップ：縦書きモードでの抑制

- [x] 6.1 縦書きモード時にはホバーポップアップが出ないこと（mark表示は維持）を `TextContentRenderer` レベルのテストで保証

## 7. 右クリックメニュー拡張：横書き（TDD）

- [ ] 7.1 `buildDictionaryContextMenu` を拡張するテスト：選択あり時に「解析開始(ネタバレなし)」「解析開始(ネタバレあり)」が追加されること、選択なし時に追加されないこと
- [ ] 7.2 実装を追加して green 化
- [ ] 7.3 メニュー項目選択時のコールバック発火テスト：選択語と SummaryType がコールバックに渡ること

## 8. 右クリックメニュー拡張：縦書き（TDD）

- [ ] 8.1 `_showVerticalContextMenu` の `PopupMenuItem` リストに2項目を追加するテスト
- [ ] 8.2 実装を追加して green 化
- [ ] 8.3 メニュー項目選択時のコールバック発火テスト

## 9. 解析起動フロー：modal とトリガー結線（TDD）

- [ ] 9.1 解析実行関数（選択語 + SummaryType を受け取り、modal を出し、`LlmSummaryService.generateSummary` を呼び、結果に応じて modal close + SnackBar）のテストを書く（成功・失敗の2ケース）
- [ ] 9.2 既存の `LlmSummaryNotifier.analyze` が `selectedTextProvider` を直接見ていた箇所を、引数で word/SummaryType を受け取れるリファクタにする（テストファースト）。`selectedTextProvider` 依存を解消
- [ ] 9.3 解析中に modal が `barrierDismissible: false` で表示され、ユーザがバリアをタップしても閉じないことを widget test で確認
- [ ] 9.4 横書き/縦書き双方の context menu コールバックから 9.1 の関数を呼ぶよう結線

## 10. 右カラム構成変更

- [ ] 10.1 `home_screen.dart` の右カラム中身を `SearchResultsPanel` 単独に差し替える widget test を書く
- [ ] 10.2 実装を反映し、`SearchSummaryPanel` ファイル（`lib/shared/widgets/search_summary_panel.dart`）を削除
- [ ] 10.3 `LlmSummaryPanel` ファイル（`lib/features/llm_summary/presentation/llm_summary_panel.dart`）を削除し、関連 import を全て掃除

## 11. 履歴タブのコピー機能（TDD）

- [ ] 11.1 履歴エントリ右クリ時の context menu に「要約をコピー(なし/あり)」項目が、エントリ種別に応じて出ることのテスト（なし のみ / あり のみ / 両 の3パターン）
- [ ] 11.2 選択時に `Clipboard.setData` が正しい文字列で呼ばれることをモックで確認するテスト
- [ ] 11.3 コピー成功時の SnackBar 表示テスト
- [ ] 11.4 `llm_summary_history_panel.dart` の実装を更新して green 化

## 12. ローカライズ・文字列

- [ ] 12.1 新規メッセージキーを `l10n/app_localizations.dart` / `app_localizations_ja.dart`（他言語も該当あれば）に追加：「解析開始(ネタバレなし)」「解析開始(ネタバレあり)」「解析中…」「『{word}』の要約を保存しました」「クリップボードにコピーしました」「別ファイルで解析した要約です」など
- [ ] 12.2 旧メッセージキー（パネル UI 用：「単語を選択してください」「設定画面でLLMを設定してください」「解析開始」など）の参照を全て削除し、不要キーは l10n からも削除

## 13. 最終確認

- [ ] 13.1 simplifyスキルを使用してコードレビューを実施
- [ ] 13.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 13.3 `fvm flutter analyze`でリントを実行
- [ ] 13.4 `fvm flutter test`でテストを実行
- [ ] 13.5 手動検証：横書きで [選択 → 右クリ → 解析開始(なし) → modal → 完了 SnackBar → 単語にmark下線 → ホバー → ポップアップ表示 → マウス離脱で消失] の一連の流れを確認
- [ ] 13.6 手動検証：両種別キャッシュ済み語ホバー時の [なし|あり] 切替動作、`sourceFile != currentFile` 警告表示
- [ ] 13.7 手動検証：縦書きで mark 側線が出ること、hover では何も起きないこと、右クリで解析開始項目が出ること
- [ ] 13.8 手動検証：履歴タブから「要約をコピー」でクリップボードに入ること
