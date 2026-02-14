## 1. データ層 - 削除メソッド追加

- [ ] 1.1 `NovelRepository`に`deleteByFolderName(String folderName)`メソッドを追加（novelsテーブルから該当レコードを削除）
- [ ] 1.2 `NovelRepository.deleteByFolderName`のユニットテストを作成（TDD: テスト先行）
- [ ] 1.3 `LlmSummaryRepository`に`deleteByFolderName(String folderName)`メソッドを追加（word_summariesテーブルから該当folder_nameの全レコードを削除）
- [ ] 1.4 `LlmSummaryRepository.deleteByFolderName`のユニットテストを作成（TDD: テスト先行）
- [ ] 1.5 `FileSystemService`に`deleteDirectory(String path)`メソッドを追加（ディレクトリを再帰的に削除）
- [ ] 1.6 `FileSystemService.deleteDirectory`のユニットテストを作成（TDD: テスト先行）

## 2. サービス層 - NovelDeleteService

- [ ] 2.1 `NovelDeleteService`クラスを`lib/features/novel_delete/data/novel_delete_service.dart`に作成。コンストラクタで`NovelRepository`、`LlmSummaryRepository`、`FileSystemService`を受け取る
- [ ] 2.2 `NovelDeleteService.delete(String folderName)`メソッドを実装（DB削除 → ファイルシステム削除の順序で実行）
- [ ] 2.3 `NovelDeleteService`のユニットテストを作成（TDD: テスト先行、各依存をモックして削除順序と呼び出しを検証）

## 3. Provider層

- [ ] 3.1 `novelDeleteServiceProvider`を作成し、`NovelDeleteService`のインスタンスを提供

## 4. UI層 - コンテキストメニューと確認ダイアログ

- [ ] 4.1 `FileBrowserPanel`の小説フォルダListTileに`GestureDetector`のセカンダリタップを追加し、`showMenu`でコンテキストメニュー（「削除」オプション）を表示
- [ ] 4.2 ライブラリルート表示時のみコンテキストメニューを有効にする（小説フォルダ内では無効）
- [ ] 4.3 確認ダイアログを実装（小説タイトル表示、赤色の「削除」ボタン、「キャンセル」ボタン）
- [ ] 4.4 確認ダイアログで「削除」選択時に`NovelDeleteService.delete()`を呼び出し、完了後に`allNovelsProvider`と`directoryContentsProvider`をinvalidateしてUI更新

## 5. 最終確認

- [ ] 5.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [ ] 5.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 5.3 `fvm flutter analyze`でリントを実行
- [ ] 5.4 `fvm flutter test`でテストを実行
