## 1. DownloadNotifierにrefreshNovelメソッドを追加

- [x] 1.1 `refreshNovel`メソッドのテストを作成: folderNameからメタデータを取得し`startDownload`を呼び出すことを検証
- [x] 1.2 並行実行ガードのテストを作成: `DownloadStatus.idle`以外の状態で`refreshNovel`を呼んだ場合にエラー状態になることを検証
- [x] 1.3 メタデータ未発見時のテストを作成: `findByFolderName`がnullを返した場合にエラー状態になることを検証
- [x] 1.4 `DownloadNotifier`に`refreshNovel(String folderName)`メソッドを実装: `libraryPathProvider`から出力パスを取得し、`NovelRepository.findByFolderName()`で保存済みURLを取得、`startDownload()`を呼び出す
- [x] 1.5 並行実行ガードを実装: `state.status != DownloadStatus.idle`の場合にエラーメッセージを設定して早期リターン

## 2. コンテキストメニューに「更新」オプションを追加

- [x] 2.1 `_showContextMenu`のテストを作成: コンテキストメニューに「更新」と「削除」の2つの項目が表示されることを検証
- [x] 2.2 `file_browser_panel.dart`の`_showContextMenu`を修正: 「削除」の前に「更新」`PopupMenuItem`を追加
- [x] 2.3 「更新」選択時のハンドラを実装: `downloadProvider`の`refreshNovel`を呼び出し、メタデータ未発見時はSnackBarでエラー表示

## 3. 更新進捗ダイアログを実装

- [x] 3.1 更新進捗ダイアログWidgetのテストを作成: ダウンロード中・完了・エラーの各状態で適切な表示がされることを検証
- [x] 3.2 更新進捗ダイアログWidgetを作成: `downloadProvider`を監視し、進捗（現在エピソード/総数/スキップ数）、完了メッセージ、エラーメッセージを表示
- [x] 3.3 「更新」選択時にダイアログを表示する処理を実装: `refreshNovel`呼び出し後にモーダルダイアログを`showDialog`で表示

## 4. 更新完了後のUI自動リフレッシュ

- [x] 4.1 更新完了後に`allNovelsProvider`と`directoryContentsProvider`がinvalidateされることをテストで検証
- [x] 4.2 `refreshNovel`完了後のinvalidate処理を実装: `allNovelsProvider`と`directoryContentsProvider`をinvalidateする

## 5. 最終確認

- [x] 5.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [x] 5.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 5.3 `fvm flutter analyze`でリントを実行
- [x] 5.4 `fvm flutter test`でテストを実行
