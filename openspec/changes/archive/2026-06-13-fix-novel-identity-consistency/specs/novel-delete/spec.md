## MODIFIED Requirements

### Requirement: Novel deletion cleans up all data
確認ダイアログで「削除」を選択した際、以下のデータソースからデータが削除されなければならない（SHALL）: novelsテーブルのレコード、word_summariesテーブルの該当フォルダの全レコード、fact_cacheテーブルの該当フォルダの全レコード、`reading_progress`テーブルの該当novel_idのレコード、`bookmarks`テーブルの該当novel_idの全レコード、ファイルシステムの小説フォルダ。削除はファイルシステムの削除が成功してからDBレコードを削除する順序で行われなければならない（SHALL）。DBレコードの削除は単一トランザクション（`db.transaction`）内で原子的に実行されなければならず（SHALL）、途中で失敗した場合はいずれのテーブルからも行が削除されてはならない（SHALL NOT）。novel_idは削除対象フォルダの葉名（`folder_name`）であり、共有規則 `resolveNovelId` がブックマーク/進捗の保存時に用いるキーと一致しなければならない（SHALL）。

#### Scenario: Successful deletion
- **WHEN** ユーザーが確認ダイアログで「削除」を選択する
- **THEN** ファイルシステムから小説フォルダが再帰的に削除される
- **AND** novelsテーブルから該当レコードが削除される
- **AND** word_summariesテーブルから該当folder_nameの全レコードが削除される
- **AND** fact_cacheテーブルから該当folder_nameの全レコードが削除される
- **AND** `reading_progress`テーブルから該当novel_id(=folder_name)のレコードが削除される
- **AND** `bookmarks`テーブルから該当novel_id(=folder_name)の全レコードが削除される

#### Scenario: Bookmarks are cascaded on deletion
- **WHEN** 削除対象の小説フォルダに対応する `bookmarks` 行が存在する状態で削除が実行される
- **THEN** 該当novel_idの全ブックマーク行が削除される
- **AND** 孤児ブックマーク行が残らない

#### Scenario: DB deletion is atomic
- **WHEN** DBレコード削除中（例: reading_progress削除後）にエラーが発生する
- **THEN** トランザクションがロールバックされ、novels / word_summaries / fact_cache / reading_progress / bookmarks のいずれの行も削除されない
- **AND** 当該小説は一貫した状態（全DB行が揃った状態）で残る

#### Scenario: Deletion order
- **WHEN** 削除処理が実行される
- **THEN** ファイルシステムの小説フォルダ削除がDBレコードの削除より先に実行される
- **AND** ファイルシステム削除が成功した場合にのみDBレコードの削除トランザクションが実行される

#### Scenario: File system deletion fails
- **WHEN** ファイルシステムの小説フォルダ削除が失敗する（例: フォルダ内のDBファイルがロックされている）
- **THEN** novelsテーブル等のDBレコードは削除されない
- **AND** 当該フォルダは小説フォルダ（メタデータ登録済み）のまま保持される
- **AND** ユーザーは同じ削除操作を再試行できる

### Requirement: NovelDeleteService orchestration
削除処理はNovelDeleteServiceに集約されなければならない（SHALL）。このサービスはNovelRepository、LlmSummaryRepository、FactCacheRepository、ReadingProgressRepository、BookmarkRepository、FileSystemServiceの削除メソッドを呼び出す。削除に先立ち、対象フォルダ内のper-folder DB（`episode_cache.db` 等）のハンドルを解放し、その解放（close）の完了を待ってからファイルシステム削除を実行しなければならない（SHALL）。ファイルシステム削除成功後、`novel_metadata.db` 上の各テーブル削除は単一の `db.transaction` 内で実行しなければならない（SHALL）。

#### Scenario: Service coordinates deletion across layers
- **WHEN** NovelDeleteService.delete(folderName)が呼び出される
- **THEN** 対象フォルダのper-folder DBハンドルが解放され、closeの完了が待たれる
- **AND** FileSystemServiceでフォルダが再帰的に削除される
- **AND** フォルダ削除成功後、単一トランザクション内でNovelRepository.deleteByFolderName()でnovels行が削除される
- **AND** 同トランザクション内でword_summariesテーブルから該当フォルダの全レコードが削除される
- **AND** 同トランザクション内でfact_cacheテーブルから該当フォルダの全レコードが削除される
- **AND** 同トランザクション内でReadingProgressRepository.deleteByNovelId(folderName)で`reading_progress`の該当行が削除される
- **AND** 同トランザクション内でBookmarkRepository.deleteByNovelId(folderName)で`bookmarks`の該当行が削除される

#### Scenario: Per-folder DB handle is released before deletion
- **WHEN** ユーザーが小説フォルダの削除を実行する
- **THEN** 削除フローは移動・リネーム・フォルダ削除と同様に対象フォルダのper-folder DBハンドルを解放する
- **AND** ハンドル解放は正規化済みフォルダパスをキーとして行われ、セパレータ差によりエントリを取りこぼさない
- **AND** 解放はclose完了をawaitできる方式で行われ、close完了前にファイルシステム削除へ進まない
