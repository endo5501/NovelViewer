## Why

ファイルブラウザ（左カラム）の横幅は `kLeftColumnWidth = 250` で固定されている。Web 小説のタイトルやエピソード名は長く、`maxLines: 1` + `TextOverflow.ellipsis` によって大半が途中で省略されるため、どの小説・どの話なのか一覧から判別しづらい。

補助手段である `Tooltip` も万全ではない。フォルダ行のツールチップは、コンテキストメニューのジェスチャ競合を避けるために `triggerMode: TooltipTriggerMode.manual` が指定されており（`file_browser_panel.dart:420`）ホバーのある環境でしか出ない。タッチ主体の iPad では、省略された名前を確認する手段が事実上存在しない。

一方で「本文を読みながらファイル一覧を眺める」という使い方は実際には行われていない。左カラムは「次に読むものを選んだら用済み」の面が強く、本文と場所を取り合う理由が薄い。

先行する iPad 対応（`adaptive-shell-layout`）で narrow レイアウトの `Drawer` 実装は既に入っている。この仕組みを全レイアウトへ広げることで、左カラムを本文と場所を取り合わない位置に移し、同時に幅を大きく広げられる。

## What Changes

### 左カラムを全レイアウトで Drawer に統一

- wide レイアウトの 3 カラム `Row` から左カラムとその `VerticalDivider` を除去する。本文は解放された幅を受け取る
- `Scaffold.drawer` を `isNarrow` 条件なしに常設する。`AppBar` のハンバーガーボタンは Flutter が自動で付与する
- Drawer の幅を `min(画面幅 - 64, 560)` とする。`kLeftColumnWidth = 250` は廃止
  - PC 1440pt → 560 / iPad 縦 744〜834pt → 560 / iPhone 縦 390pt → 326
- 既存の `SafeArea` によるインセットと `drawerEnableOpenDragGesture: false` は、条件分岐なしに常時適用となる（デスクトップではパディングが 0 なので無影響）

これにより `adaptive-shell-layout` の「drawer は wide レイアウトの左カラムと同じ幅を使う」という要件は意図的に破棄される。

### 起動時に Drawer を開く

- 起動時、`readingProgressStartupProvider`（`reading_progress_providers.dart:82`）が決着した後に Drawer を開く
- 復元ロジック自体は一切変更しない。既存の復元は `setDirectory` + `selectFile` まで完了するため、Drawer を開いた時点で `_controllerForViewport` が前回のエピソード行を画面中央に配置する
- 復元対象がない初回起動でも Future は完了するため、ライブラリルートの一覧が未選択のまま表示される
- 決着を待ってから開くのは、走査中に一覧がルート → エピソード一覧へ差し替わる様子をユーザーに見せないため

### **BREAKING** ペイン切替ショートカットを Drawer トグルへ置き換え

- `ShortcutAction.switchPane` を削除する。`FocusScopeNode` 間のフォーカス移動は視覚的な変化を伴わず、押しても何も起きていないように見えるため、機能として成立していない
- `ShortcutAction.toggleFileBrowser` を新設し、既定キーを `Tab` とする
- 「テキスト入力中は無効」のガード（`isTextInputFocused()`）は新アクションへ引き継ぐ。検索ボックス入力中に `Tab` が奪われない
- 保存済みの旧 `switchPane` バインディングは `runStartupMigrations` で除去する
- `_fileBrowserPaneFocus`、`initState` の起動時フォーカス要求、`if (!isNarrow) ShortcutAction.switchPane` の分岐は不要になり削除される

### Esc の優先順位に Drawer を追加

- グローバル Esc ハンドラ（`_handleGlobalEscape`）の先頭に「Drawer が開いていれば閉じる」を追加する。以降の順序（検索セッション終了 → TTS 停止）は現行どおり
- 結果として、Drawer が開いている間は検索セッションが有効でも Esc が先に Drawer を閉じる。`text-search` の "global Escape handler" シナリオにこの条件を明示する必要がある

### 変更しないもの（Non-goals）

- **右カラム（検索結果）は一切変更しない。** 既定非表示・検索時のみ表示、wide では列 / narrow では `endDrawer`、`shellBreakpointProvider = 800` のいずれも据え置き
- ドラッグでカラム幅を変えるリサイズ可能な仕切りは導入しない
- ファイル一覧の行にキーボードフォーカス（行ごとの `FocusNode`）を持たせ、`Enter` で確定する仕組みは導入しない。復元が `selectFile` まで済ませるため、Drawer を閉じれば読書が再開する
- 読書位置・読書進捗の復元ロジックそのものは変更しない
- `Cmd/Ctrl+E` のような Drawer 専用の追加キーは設けない。`Tab` とハンバーガーボタンで足りる

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `adaptive-shell-layout`: 左カラムは幅に依らず常に `Drawer` に置かれる。「drawer は wide の左カラムと同じ幅」要件を廃し、画面幅追従の幅（`min(画面幅 - 64, 560)`）に置き換える。`SafeArea` インセットとエッジドラッグ無効化は narrow 限定ではなく常時適用になる。起動時、読書セッション復元の決着後に Drawer を開く要件を追加する。narrow / wide の判定自体は残るが、その差は「右カラムを列として置けるか」だけになる
- `three-column-layout`: 左カラムが `Row` の構成要素でなくなる。「wide では 250px の固定ペイン」「narrow では同幅の Drawer」という要件を、「レイアウトに依らず Drawer に置かれ、幅は画面幅に追従する」へ置き換える。タブ構成（ファイル / ブックマーク / 条件付きの履歴、既定はファイルタブ）は変更しない
- `keyboard-shortcuts`: 「ペイン間フォーカス切替（Tab限定）」要件を削除し、「ファイルブラウザ Drawer のトグル（既定 `Tab`）」要件に置き換える。narrow レイアウトでバインディングを登録しないという条件も、Drawer が常設になるため不要になる
- `text-search`: グローバル Esc ハンドラのシナリオに「Drawer が閉じている状態で」という前提条件を追加する。検索終了時のハイライト消去という振る舞い自体は変わらない

`column-visibility-toggle` と `file-browser` は要件の変更なし（前者は右カラムの扱いが不変、後者は描画幅が変わるのみ）。

## Impact

### 変更されるコード

- `lib/home_screen.dart`: `kLeftColumnWidth` 廃止、`drawer` の常設化と幅の算出、wide の `Row` から左カラム除去、起動時の Drawer オープン、`_handleGlobalEscape` の優先順位、`_fileBrowserPaneFocus` と `_switchPane` / `_SwitchPaneAction` の削除、`Shortcuts` マップの narrow 分岐削除
- `lib/features/keyboard_shortcuts/data/shortcut_action.dart`: `switchPane` 削除 / `toggleFileBrowser` 追加
- `lib/features/keyboard_shortcuts/data/shortcut_bindings.dart`: 既定バインディング差し替え
- `lib/features/keyboard_shortcuts/data/shortcut_intents.dart`: Intent の差し替え
- `lib/app/startup_migrations.dart`: 保存済み `switchPane` バインディングの除去
- `lib/l10n/*.arb`: 新アクションのラベル（設定画面のショートカット一覧に表示される）を ja / en / zh に追加

### 変更されるテスト

- `test/home_screen_adaptive_shell_test.dart`: 左カラムに関する wide レイアウトの期待値
- `test/home_screen_pane_focus_test.dart`: ペイン切替が消えるため実質削除
- `test/home_screen_dynamic_shortcuts_test.dart`: 登録されるショートカットの集合
- `test/shared/layout/shell_layout_test.dart` / `test/shared/providers/layout_providers_test.dart`: 判定の意味が右カラム限定になることの反映

### リスク

- `Tab` は本来フォーカス移動キーであり、Drawer トグルに充てると本文側でのフォーカス移動に使えなくなる。ただし現状も `switchPane` が `Tab` を占有しているため、実質的な後退はない
- 起動時の復元は非同期のディレクトリ走査を含むため、ライブラリの規模によっては Drawer が開くまでの待ち時間が体感できる可能性がある
