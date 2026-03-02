## 1. Repository層（タイトル更新メソッド）

- [x] 1.1 NovelRepositoryにupdateTitleメソッドのテストを作成（folderName指定でtitleとupdated_atが更新されること、存在しないfolderNameで例外がスローされること）
- [x] 1.2 NovelRepositoryにupdateTitleメソッドを実装

## 2. UI層（コンテキストメニュー拡張）

- [x] 2.1 file_browser_panel.dartのコンテキストメニューに「タイトル変更」オプションを追加（「更新」と「削除」の間に配置）
- [x] 2.2 タイトル変更ダイアログのWidgetテストを作成（現在のタイトルがプリフィルされること、空文字列で変更ボタンが無効化されること、キャンセルでダイアログが閉じること）
- [x] 2.3 タイトル変更ダイアログを実装（TextFieldに現在のタイトルをプリフィル、空文字列バリデーション、「変更」「キャンセル」ボタン）

## 3. 統合（タイトル変更フロー）

- [x] 3.1 コンテキストメニューの「タイトル変更」選択時にダイアログ表示→DB更新→allNovelsProvider invalidate→UI更新の一連のフローを接続
- [x] 3.2 統合テストを作成（タイトル変更後にファイルブラウザの表示が更新されること）

## 4. 最終確認

- [x] 4.1 simplifyスキルを使用してコードレビューを実施
- [x] 4.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 4.3 `fvm flutter analyze`でリントを実行
- [x] 4.4 `fvm flutter test`でテストを実行
