## MODIFIED Requirements

### Requirement: Novel deletion cleans up all data
確認ダイアログで「削除」を選択した際、以下の4つのデータソースからデータが削除されなければならない（SHALL）: novelsテーブルのレコード、word_summariesテーブルの該当フォルダの全レコード、`reading_progress`テーブルの該当novel_idのレコード、ファイルシステムの小説フォルダ。削除はファイルシステムの削除が成功してからDBレコードを削除する順序で行われなければならない（SHALL）。

#### Scenario: Successful deletion
- **WHEN** ユーザーが確認ダイアログで「削除」を選択する
- **THEN** ファイルシステムから小説フォルダが再帰的に削除される
- **AND** novelsテーブルから該当レコードが削除される
- **AND** word_summariesテーブルから該当folder_nameの全レコードが削除される
- **AND** `reading_progress`テーブルから該当novel_id(=folder_name)のレコードが削除される

#### Scenario: Deletion order
- **WHEN** 削除処理が実行される
- **THEN** ファイルシステムの小説フォルダ削除がDBレコードの削除より先に実行される
- **AND** ファイルシステム削除が成功した場合にのみDBレコードが削除される

#### Scenario: File system deletion fails
- **WHEN** ファイルシステムの小説フォルダ削除が失敗する（例: フォルダ内のDBファイルがロックされている）
- **THEN** novelsテーブル等のDBレコードは削除されない
- **AND** 当該フォルダは小説フォルダ（メタデータ登録済み）のまま保持される
- **AND** ユーザーは同じ削除操作を再試行できる

### Requirement: NovelDeleteService orchestration
削除処理はNovelDeleteServiceに集約されなければならない（SHALL）。このサービスはNovelRepository、LlmSummaryRepository、ReadingProgressRepository、FileSystemServiceの削除メソッドを呼び出す。削除に先立ち、対象フォルダ内のper-folder DB（`episode_cache.db` 等）のハンドルを解放し、その解放（close）の完了を待ってからファイルシステム削除を実行しなければならない（SHALL）。

#### Scenario: Service coordinates deletion across layers
- **WHEN** NovelDeleteService.delete(folderName)が呼び出される
- **THEN** 対象フォルダのper-folder DBハンドルが解放され、closeの完了が待たれる
- **AND** FileSystemServiceでフォルダが再帰的に削除される
- **AND** フォルダ削除成功後にNovelRepository.deleteByFolderName()でDBレコードが削除される
- **AND** word_summariesテーブルから該当フォルダの全レコードが削除される
- **AND** ReadingProgressRepository.deleteByNovelId(folderName)で`reading_progress`の該当行が削除される

#### Scenario: Per-folder DB handle is released before deletion
- **WHEN** ユーザーが小説フォルダの削除を実行する
- **THEN** 削除フローは移動・リネーム・フォルダ削除と同様に対象フォルダのper-folder DBハンドルを解放する
- **AND** ハンドル解放は正規化済みフォルダパスをキーとして行われ、セパレータ差によりエントリを取りこぼさない
- **AND** 解放はclose完了をawaitできる方式で行われ、close完了前にファイルシステム削除へ進まない
