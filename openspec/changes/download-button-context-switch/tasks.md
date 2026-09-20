## 1. 更新対象の導出

- [x] 1.1 `test/features/novel_refresh/refresh_target_provider_test.dart` を作成し、`refreshTargetProvider` の全分岐を `ProviderContainer` で検証するテストを書く（表示中ファイル無し → null / 登録済み小説のエピソード → `folderName`・`parentPath`・`title` が解決される / 整理用サブフォルダに入れ子の小説 → 親がそのサブフォルダになる / 登録済み小説フォルダを含まないパス → null / Web 記事コレクション → null / ファイルブラウザの現在地を別ディレクトリへ動かしても結果が変わらない）。`fvm flutter test test/features/novel_refresh/refresh_target_provider_test.dart` が失敗することを確認する
- [x] 1.2 テストが正しいことを確認した時点でコミットする（実装は含めない）
- [x] 1.3 `lib/features/novel_refresh/domain/refresh_target.dart` に `RefreshTarget`（`folderName` / `parentPath` / `title`）を追加し、`lib/features/novel_refresh/providers/refresh_target_provider.dart` に `refreshTargetProvider` を実装する。解決には `resolveNovelFolderPath` を用い、Web 記事コレクションを除外する。1.1 のテストが全て通ることを確認する

## 2. 更新の起動と進捗ダイアログの切り出し

- [x] 2.1 `test/features/novel_refresh/refresh_progress_dialog_test.dart` を作成し、`RefreshProgressDialog` を直接組み立てて検証するテストを書く（`downloading` 中は有効なキャンセルボタンが表示される / キャンセル押下で `DownloadNotifier.cancel()` が呼ばれる / `cancelled` 状態ではキャンセルメッセージと「閉じる」が表示され赤いエラー表示にならない / `downloading` 中は「閉じる」が無い / 完了・エラー時の既存表示が保たれる）。テストが失敗することを確認する
- [x] 2.2 `test/features/novel_refresh/start_novel_refresh_test.dart` を作成し、`startNovelRefresh` を検証するテストを書く（ダウンロード実行中に呼ぶと SnackBar で警告し `refreshNovel` を呼ばない / 待機中に呼ぶと `refreshNovel` が渡した `folderName`・`parentPath` で呼ばれ進捗ダイアログが表示される）。テストが失敗することを確認する
- [x] 2.3 テストが正しいことを確認した時点でコミットする（実装は含めない）
- [x] 2.4 `lib/features/novel_refresh/presentation/refresh_progress_dialog.dart` を作成し、`file_browser_panel.dart` の `_RefreshProgressDialog` を `RefreshProgressDialog` として移設したうえで、`downloading` 中のキャンセルボタン（`common_cancelButton` / `download_cancelledMessage` を再利用）を追加する。同ファイルに `startNovelRefresh` を実装し、`_startRefresh` の並行ガードと起動処理を移す。2.1 と 2.2 のテストが通ることを確認する
- [x] 2.5 `file_browser_panel.dart` の `_startRefresh` と `_RefreshProgressDialog` を削除し、コンテキストメニューの「更新」を `startNovelRefresh` 呼び出しに置き換える。`fvm flutter test test/features/file_browser test/features/text_download` が通ることを確認する
- [x] 2.6 旧 `test/features/file_browser/presentation/refresh_progress_dialog_test.dart`（本物のダイアログを組み立てられず代替ウィジェットを検証していたもの）を削除し、カバー範囲が 2.1 に引き継がれていることを確認する

## 3. AppBar ボタンの文脈切り替え

- [ ] 3.1 `test/home_screen_download_button_test.dart` を作成し、AppBar ボタンの2状態を検証するウィジェットテストを書く（更新対象が解決できる場合は `Icons.sync` と更新ツールチップ・押下で `refreshNovel` が呼ばれ進捗ダイアログが出る / 解決できない場合は `Icons.download` とダウンロードツールチップ・押下で `DownloadDialog` が出る / どちらの状態でもボタンは有効 / 更新完了後も更新状態が保たれる / ダウンロード実行中に押すと SnackBar 警告のみで新たな更新が始まらない）。テストが失敗することを確認する
- [ ] 3.2 テストが正しいことを確認した時点でコミットする（実装は含めない）
- [ ] 3.3 `lib/home_screen.dart` の AppBar ダウンロードボタンを `refreshTargetProvider` の値で分岐させる。解決できる場合は `Icons.sync` + 更新ツールチップ + `startNovelRefresh`、解決できない場合は現状どおり `Icons.download` + `_openDownloadDialog`。3.1 のテストが通ることを確認する
- [ ] 3.4 既存の `test/home_screen_test.dart` / `test/home_screen_download_request_test.dart` / `test/home_screen_adaptive_shell_test.dart` が通ることを確認する。外部からのダウンロード要求がボタンの状態に影響されないことが担保されていない場合は、そのケースを `test/home_screen_download_request_test.dart` に追加する

## 4. ファイルブラウザのツールバーに新規ダウンロードボタン

- [ ] 4.1 `test/features/file_browser/presentation/toolbar_download_button_test.dart` を作成し、ツールバーの新規ダウンロードボタンを検証するテストを書く（ライブラリルートでも整理用サブフォルダでも小説フォルダでもボタンが表示され有効 / 押下で `DownloadDialog` が表示される）。テストが失敗することを確認する
- [ ] 4.2 テストが正しいことを確認した時点でコミットする（実装は含めない）
- [ ] 4.3 `file_browser_panel.dart` の `_buildToolbar` に `Icons.download` のボタンを追加し、`DownloadDialog.show` を呼ぶ。4.1 のテストが通ることを確認する

## 5. ローカライズ

- [ ] 5.1 `lib/l10n/app_ja.arb` / `app_en.arb` / `app_zh.arb` に AppBar の更新ツールチップとファイルブラウザのダウンロードボタンのツールチップを追加する。`fvm flutter pub get`（または `gen-l10n`）を実行し、未翻訳の警告が出ないことを確認する
- [ ] 5.2 `test/l10n/` の既存パリティテストを実行し、3言語のキーが揃っていることを確認する

## 6. 最終確認

- [ ] 6.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 6.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 6.3 `fvm dart format .`でフォーマットを実行
- [ ] 6.4 `fvm flutter analyze`でリントを実行
- [ ] 6.5 `fvm flutter test`でテストを実行
