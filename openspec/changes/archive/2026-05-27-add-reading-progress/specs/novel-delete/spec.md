## MODIFIED Requirements

### Requirement: Novel deletion cleans up all data
確認ダイアログで「削除」を選択した際、以下の4つのデータソースからデータが削除されなければならない（SHALL）: novelsテーブルのレコード、word_summariesテーブルの該当フォルダの全レコード、`reading_progress`テーブルの該当novel_idのレコード、ファイルシステムの小説フォルダ。

#### Scenario: Successful deletion
- **WHEN** ユーザーが確認ダイアログで「削除」を選択する
- **THEN** novelsテーブルから該当レコードが削除される
- **AND** word_summariesテーブルから該当folder_nameの全レコードが削除される
- **AND** `reading_progress`テーブルから該当novel_id(=folder_name)のレコードが削除される
- **AND** ファイルシステムから小説フォルダが再帰的に削除される

#### Scenario: Deletion order
- **WHEN** 削除処理が実行される
- **THEN** DBレコードの削除がファイルシステム削除より先に実行される

### Requirement: NovelDeleteService orchestration
削除処理はNovelDeleteServiceに集約されなければならない（SHALL）。このサービスはNovelRepository、LlmSummaryRepository、ReadingProgressRepository、FileSystemServiceの削除メソッドを呼び出す。

#### Scenario: Service coordinates deletion across layers
- **WHEN** NovelDeleteService.delete(folderName)が呼び出される
- **THEN** NovelRepository.deleteByFolderName()でDBレコードが削除される
- **AND** word_summariesテーブルから該当フォルダの全レコードが削除される
- **AND** ReadingProgressRepository.deleteByNovelId(folderName)で`reading_progress`の該当行が削除される
- **AND** FileSystemServiceでフォルダが削除される
