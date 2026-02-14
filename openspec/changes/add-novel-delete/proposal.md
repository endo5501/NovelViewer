## Why

ダウンロードした小説を削除する手段がアプリに存在しない。手動でフォルダを削除してもDBに残骸（novelsレコード、word_summariesレコード）が残り、ファイルブラウザの表示が壊れる。小説の管理ライフサイクルを完結させるために、DB・ファイルシステム両方を適切にクリーンアップする削除機能が必要。

## What Changes

- ファイルブラウザで小説フォルダを右クリックした際に「削除」オプション付きのコンテキストメニューを表示
- 削除前に確認ダイアログを表示し、誤操作を防止
- 削除実行時に以下を一括クリーンアップ:
  - `novels`テーブルから該当レコードを削除
  - `word_summaries`テーブルから該当フォルダの全サマリーを削除
  - ファイルシステムから小説フォルダとその中の全エピソードファイルを削除
- 削除後にUIを自動更新し、削除された小説がファイルブラウザから消える

## Capabilities

### New Capabilities

- `novel-delete`: 小説フォルダの削除機能。DB（novels, word_summaries）とファイルシステムの両方からデータを削除し、UIを更新する

### Modified Capabilities

- `novel-metadata-db`: NovelRepositoryに削除メソッドを追加。word_summariesの連動削除も含む

## Impact

- **データ層**: `NovelRepository`に`deleteByFolderName`メソッド追加、`LlmSummaryRepository`にフォルダ単位の一括削除メソッド追加
- **ファイルシステム**: `FileSystemService`にディレクトリ削除メソッド追加
- **UI**: `FileBrowserPanel`にコンテキストメニューと確認ダイアログを追加
- **状態管理**: 削除後に`allNovelsProvider`と`directoryContentsProvider`を無効化してUI更新
- **破壊的操作**: 削除は不可逆なため、確認ダイアログが必須
