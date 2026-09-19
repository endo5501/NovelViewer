## 1. Drawer 幅のピュア関数

- [x] 1.1 `test/shared/layout/shell_layout_test.dart` に隣接する形で `fileBrowserDrawerWidth` のユニットテストを書く。境界値は「1440pt → 560（上限に張り付く）」「390pt → 326（表示幅 − 64）」「624pt → 560（上限ちょうど）」。`fvm flutter test` が未実装により失敗することを確認する
- [x] 1.2 `lib/shared/layout/shell_layout.dart` に `fileBrowserDrawerWidth({required double displayWidth})` と上限・インセットの名前付き定数を追加し、1.1 のテストが通ることを確認する（design D1）

## 2. ショートカットアクションの入れ替え

- [x] 2.1 既定バインディングのテストを更新・追加し、`toggleFileBrowser` の既定が修飾子なしの `Tab` であること、`switchPane` が `ShortcutAction.values` に存在しないことを検証する。未実装により失敗することを確認する
- [x] 2.2 保存済み設定から廃止アクションのエントリが除去されることのテストを書く。「廃止済みエントリが消える」「現存アクションのカスタマイズは保持される」「解放されたキーを別アクションへ割り当てられる」の3ケース。未実装により失敗することを確認する
- [x] 2.3 `ShortcutAction.switchPane` を削除し `toggleFileBrowser` を追加。`shortcut_bindings.dart` の既定値と dartdoc、`shortcut_intents.dart` の `Intent`（`SwitchPaneIntent` → `ToggleFileBrowserIntent`）を差し替え、2.1 が通ることを確認する（design D5）
- [x] 2.4 `lib/app/startup_migrations.dart` に廃止アクションのバインディング除去を追加する。既存の `migrateApiKeyToSecureStorage` と同じく try/catch で包み、失敗が起動を妨げないようにして 2.2 が通ることを確認する（design D6）
- [x] 2.5 `lib/l10n/app_ja.arb` / `app_en.arb` / `app_zh.arb` の `shortcutAction_switchPane` を `shortcutAction_toggleFileBrowser` に差し替え（ja「ファイル一覧の表示切替」/ en "Toggle file browser" / zh 相当）、`lib/features/keyboard_shortcuts/presentation/shortcut_settings_section.dart` の `switch` を更新する。`fvm flutter analyze` が通り、設定画面に新しいラベルが出ることを確認する

## 3. home_screen の再構成

- [ ] 3.1 `test/home_screen_adaptive_shell_test.dart` を更新し、wide レイアウトでも左カラムが `body` になく `Drawer` にあること、`Drawer` の幅が `fileBrowserDrawerWidth` と一致することを検証するケースを追加する。未実装により失敗することを確認する
- [ ] 3.2 `Scaffold.drawer` を `isNarrow` 条件なしに常設し、幅に `fileBrowserDrawerWidth` を渡す。`kLeftColumnWidth` を削除し、`SafeArea` と `drawerEnableOpenDragGesture: false` を分岐なしで適用して 3.1 が通ることを確認する
- [ ] 3.3 `body` を1本の `Row` に統一する。左カラムとその `VerticalDivider` を除去し、右カラムは `!isNarrow && rightColumnVisible` のときだけ足す。`isNarrow` の参照が `endDrawer` の生成・右カラムの追加・AppBar のトグルボタンの3箇所だけになったことを確認する（design D4）
- [ ] 3.4 `_fileBrowserPaneFocus` / `_switchPane` / `_SwitchPaneAction` と `initState` の post-frame フォーカス要求を削除し、`ToggleFileBrowserIntent` を `Drawer` の開閉につなぐ `Action`（`isEnabled` は `!isTextInputFocused()`）を配線する。`Shortcuts` マップ構築の `if (!isNarrow)` 条件を削除する（design D5）
- [ ] 3.5 Tab による `Drawer` 開閉のウィジェットテストを追加する。「閉→開」「開→閉」「wide / narrow の両方で登録される」「検索入力にフォーカスがある間は発火しない」の4ケースが通ることを確認する

## 4. Esc の優先順位

- [ ] 4.1 Esc の2段階動作のウィジェットテストを書く。「検索中にファイルブラウザ `Drawer` を開いて Esc → `Drawer` だけ閉じ、`searchQuery` は保持」「続けて Esc → 検索終了」「`Drawer` が閉じているときは従来どおり」「narrow で `endDrawer` だけが開いているときは従来どおり一度の押下で検索終了」。未実装により失敗することを確認する
- [ ] 4.2 `_handleGlobalEscape` の `isTextInputFocused()` ガード直後に、左 `Drawer` が開いていれば閉じて `true` を返す分岐を追加する。`endDrawer` は対象に含めず、4.1 が通ることを確認する（design D3）

## 5. 起動時の Drawer オープン

- [ ] 5.1 起動時オープンのウィジェットテストを書く。`readingProgressStartupProvider` を `Completer` 制御の override に差し替え、「未決着の間は `Drawer` が閉じている」「決着後に開く」「復元が失敗しても開く」「初回 build 時点で既に決着していても開く」の4ケース。未実装により失敗することを確認する
- [ ] 5.2 `HomeScreen` で `readingProgressStartupProvider` を購読し、決着（`AsyncData` / `AsyncError`）で一度だけ `openDrawer()` を呼ぶ。`ref.listen` は遷移しか拾わないため初回 build 時の現在値も確認し、`_startupDrawerOpened` フラグで多重実行を防いで 5.1 が通ることを確認する（design D2）

## 6. 既存テストの整理

- [ ] 6.1 `test/home_screen_pane_focus_test.dart` を削除する（`switchPane` の廃止により対象機能が存在しない）
- [ ] 6.2 `test/home_screen_dynamic_shortcuts_test.dart` を更新し、`toggleFileBrowser` が wide / narrow のどちらでも登録されることを検証する
- [ ] 6.3 `test/shared/providers/layout_providers_test.dart` と `test/shared/layout/shell_layout_test.dart` を見直し、narrow / wide の判定が右カラムの置き場所だけを決める前提に合わせる。breakpoint 800 と `kMinimumWindowSize` の一致を確認するテストは維持する
- [ ] 6.4 `fvm flutter test` 全体を実行し、左カラムの固定幅や起動時フォーカスに依存していた他のテストがないことを確認する

## 7. 実機確認

- [ ] 7.1 macOS で `fvm flutter run -d macos` を実行し、起動時に `Drawer` が開いて前回のエピソードが選択済みで中央に表示されること、長いファイル名が省略されずに読めること、`Tab` と Esc が期待どおり動くことを目視で確認する
- [ ] 7.2 起動時に `Drawer` が開くまでの待ち時間が許容範囲か確認する。体感できるほど遅い場合は design の Risks に記載した代替案（プレースホルダ表示、または D2 却下案の再検討）を検討対象として記録する

## 8. 最終確認

- [ ] 8.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 8.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 8.3 `fvm dart format .`でフォーマットを実行
- [ ] 8.4 `fvm flutter analyze`でリントを実行
- [ ] 8.5 `fvm flutter test`でテストを実行
- [ ] 8.6 `/opsx:sync` で delta spec を本体へ同期した後、`openspec/specs/adaptive-shell-layout/spec.md` と `openspec/specs/three-column-layout/spec.md` の `## Purpose` を手で更新する（delta spec の Purpose は同期時に無視されるため。design D7）
