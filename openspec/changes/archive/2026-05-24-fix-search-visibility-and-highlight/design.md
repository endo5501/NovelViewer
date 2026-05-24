## Context

検索 UI のリファクタで LLM 解析 UI がポップアップメニューへ移動し、右カラム (`SearchResultsPanel`) は検索専用領域となった。状態は Riverpod の `NotifierProvider` 群で管理されている。

- `rightColumnVisibleProvider` (`lib/shared/providers/layout_providers.dart`): 右カラムの表示状態。
- `searchBoxVisibleProvider` (`lib/features/text_search/providers/text_search_providers.dart`): 検索ボックスの表示状態。
- `searchQueryProvider`: 検索クエリ文字列。
- `selectedSearchMatchProvider`: 検索結果からクリックで選択された個別マッチ (filePath / lineNumber / query)。テキストハイライトの描画はこの provider の `query` を読み取って行う (`text_content_renderer.dart:240`)。

「クエリ入力」と「特定マッチへのジャンプ」を切り分け、クエリだけでは自動ジャンプせず、結果リストのクリックで初めてジャンプ・ハイライトする設計になっている。この意図は保持する。

## Goals / Non-Goals

**Goals:**

- 起動時に空の右カラムを画面に表示しない (画面占有を解消)。
- Ctrl+F (またはトグルボタン) で右カラムにアクセスできる導線を維持する。
- 検索終了 (Esc) およびクエリクリア時にハイライトを完全に消去する。
- 既存テストを正しく更新し、新しい挙動を回帰防止する。

**Non-Goals:**

- 検索アルゴリズムや検索結果表示形式の変更。
- ハイライトの色・スタイルの変更。
- 横書きクリックジャンプの位置ズレ問題 (別 change `fix-horizontal-text-jump` で対応)。
- 右カラムのレイアウト変更や AppBar ボタンの除去。

## Decisions

### 決定 1: 右カラムのデフォルトを `false` (非表示) にする

`RightColumnVisibleNotifier.build()` の戻り値を `true` から `false` に変更する。

**代替案**:
- (案 X) `searchBoxVisibleProvider` を真とした時のみ右カラムを描画する条件式に変更する → AppBar トグルボタンによる手動表示動線を壊すため不採用。
- (案 Y) 起動時のみ非表示にし、その後はユーザー操作に従う設定永続化 → 過剰設計。本不具合は「初期表示」が問題のため Notifier 初期値変更で十分。

採用理由: 既存の `home_screen.dart:117-121` に Ctrl+F 時の自動表示ロジックがあり、デフォルト変更だけで「Ctrl+F で開く / トグルボタンで開く」両方が成立する。

### 決定 2: ハイライトクリアは「クエリ消去/Esc」を行う既存箇所で `selectedSearchMatchProvider.clear()` を併せて呼ぶ (案 A)

Esc/クリアを実装している 2 箇所:
- `home_screen.dart:_handleEscapeKey` (Esc キーでの大域ハンドラ)
- `search_results_panel.dart:_onEscape` (検索ボックスフォーカス時の Esc)

両者ともに `searchQueryProvider.setQuery(null)` の直後 (または直前) で `selectedSearchMatchProvider.clear()` を呼ぶ。

**代替案**:
- (案 B) ハイライト描画源を `searchQueryProvider` に切り替える → 「クエリ入力だけでは自動ジャンプしない」という既存設計意図を壊す。`text_content_renderer.dart:334-342` の `_scrollToLineNumber` 起動条件 (activeMatch != null) も影響を受け、リスクが大きい。
- (案 C) `SearchQueryNotifier.setQuery(null)` のタイミングで `selectedSearchMatchProvider` を ref 経由で同時クリア → provider 間の依存方向を増やすため、Notifier 内部から他の Notifier を触る形になり保守性が下がる。呼び出し側 (UI 層) で同時に呼ぶ方が依存方向が綺麗。

採用理由: 局所修正で済み、既存テスト構造を大きく変えずに対応できる。

## Risks / Trade-offs

- **[Risk]** デフォルト非表示化により「初期に右カラムが見える」前提のテストが失敗する → **Mitigation**: `test/home_screen_test.dart` の関連ケースを修正。初期非表示を確認するテストも追加する。
- **[Risk]** Esc/クリア時に `selectedSearchMatchProvider.clear()` 呼び忘れの箇所が他にも存在する可能性 → **Mitigation**: `searchQueryProvider.notifier).setQuery(null)` を grep し、すべての呼び出し箇所を確認した上で必要箇所すべてに clear を追加。
- **[Trade-off]** ハイライト消去責務を UI 層 (2 箇所) に持たせるため、将来 setQuery(null) を別の場所から呼ぶ際に clear 呼び忘れリスクが残る → 受容。テストでカバーする。

## Migration Plan

- 設定の永続化や DB スキーマ変更は無し。デプロイ後の追加対応不要。
- 既存ユーザーは初回起動時に右カラムが閉じた状態になるが、AppBar トグルボタンで即座に開ける。
