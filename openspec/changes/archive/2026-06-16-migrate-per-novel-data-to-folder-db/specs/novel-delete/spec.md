## MODIFIED Requirements

### Requirement: Novel deletion cleans up all data
確認ダイアログで「削除」を選択した際、以下のデータが削除されなければならない（SHALL）: `novels`テーブルの該当レコード、`reading_progress`テーブルの該当novel_idのレコード、ファイルシステムの小説フォルダ（その中の `novel_data.db` を含む）。`word_summaries`・`fact_cache`・`bookmarks` は `novel_data.db` に格納されており、小説フォルダの削除によってDBファイルごと物理的に消えるため、`novel_metadata.db` 上での明示的なレコード削除は行わない（SHALL NOT）。削除はファイルシステムの削除が成功してから `novel_metadata.db` のレコードを削除する順序で行われなければならない（SHALL）。`novel_metadata.db` 上の `novels` と `reading_progress` の削除は単一トランザクション（`db.transaction`）内で原子的に実行されなければならず（SHALL）、途中で失敗した場合はいずれの行も削除されてはならない（SHALL NOT）。novel_idは削除対象フォルダの葉名（`folder_name`）であり、共有規則 `resolveNovelId` が進捗の保存時に用いるキーと一致しなければならない（SHALL）。

#### Scenario: Successful deletion
- **WHEN** ユーザーが確認ダイアログで「削除」を選択する
- **THEN** ファイルシステムから小説フォルダが再帰的に削除される（`novel_data.db` を含む）
- **AND** `novels`テーブルから該当レコードが削除される
- **AND** `reading_progress`テーブルから該当novel_id(=folder_name)のレコードが削除される
- **AND** `word_summaries` / `fact_cache` / `bookmarks` は `novel_data.db` ごと消滅し、`novel_metadata.db` 上での個別削除は実行されない

#### Scenario: Per-novel data is removed with the folder
- **WHEN** 削除対象の小説に要約・fact・ブックマークが存在する状態で削除が実行される
- **THEN** それらは `novel_data.db` ファイルの削除により消滅する
- **AND** いずれのデータベースにも孤児行が残らない

#### Scenario: DB deletion is atomic
- **WHEN** `novel_metadata.db` のレコード削除中（例: novels削除後）にエラーが発生する
- **THEN** トランザクションがロールバックされ、`novels` / `reading_progress` のいずれの行も削除されない
- **AND** 当該小説は一貫した状態で残る

#### Scenario: Deletion order
- **WHEN** 削除処理が実行される
- **THEN** ファイルシステムの小説フォルダ削除が `novel_metadata.db` レコードの削除より先に実行される
- **AND** ファイルシステム削除が成功した場合にのみ `novels`/`reading_progress` の削除トランザクションが実行される

#### Scenario: File system deletion fails
- **WHEN** ファイルシステムの小説フォルダ削除が失敗する（例: フォルダ内のDBファイルがロックされている）
- **THEN** `novel_metadata.db` のレコードは削除されない
- **AND** 当該フォルダは小説フォルダ（メタデータ登録済み）のまま保持される
- **AND** ユーザーは同じ削除操作を再試行できる

### Requirement: NovelDeleteService orchestration
削除処理はNovelDeleteServiceに集約されなければならない（SHALL）。このサービスはNovelRepository、ReadingProgressRepository、FileSystemServiceの削除メソッドを呼び出す。`word_summaries`/`fact_cache`/`bookmarks` の削除リポジトリ呼び出しは行わない（これらはフォルダ削除で消える）。削除に先立ち、対象フォルダ内のper-folder DB（`episode_cache.db` / `tts_audio.db` / `tts_dictionary.db` / `novel_data.db`）のハンドルを解放し、その解放（close）の完了を待ってからファイルシステム削除を実行しなければならない（SHALL）。ファイルシステム削除成功後、`novel_metadata.db` 上の `novels` と `reading_progress` の削除は単一の `db.transaction` 内で実行しなければならない（SHALL）。

#### Scenario: Service coordinates deletion across layers
- **WHEN** NovelDeleteService.delete(folderName)が呼び出される
- **THEN** 対象フォルダのper-folder DBハンドル（`novel_data.db` を含む4種）が解放され、closeの完了が待たれる
- **AND** FileSystemServiceでフォルダが再帰的に削除される
- **AND** フォルダ削除成功後、単一トランザクション内でNovelRepository.deleteByFolderName()でnovels行が削除される
- **AND** 同トランザクション内でReadingProgressRepository.deleteByNovelId(folderName)で`reading_progress`の該当行が削除される
- **AND** `word_summaries`/`fact_cache`/`bookmarks` の個別削除呼び出しは行われない

#### Scenario: Per-folder DB handle is released before deletion
- **WHEN** ユーザーが小説フォルダの削除を実行する
- **THEN** 削除フローは移動・リネーム・フォルダ削除と同様に対象フォルダのper-folder DBハンドル（`novel_data.db` を含む）を解放する
- **AND** ハンドル解放は正規化済みフォルダパスをキーとして行われ、セパレータ差によりエントリを取りこぼさない
