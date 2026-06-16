## Purpose

ライブラリ画面で右クリックから小説フォルダを削除する機能。確認ダイアログで誤操作を防ぎ、`NovelDeleteService` 経由で novels テーブル / word_summaries テーブル / ファイルシステムの3層を一貫して削除し、削除後にファイルブラウザを自動更新する。
## Requirements
### Requirement: Context menu on novel folder
ライブラリルートでの小説フォルダ表示時、フォルダのListTileを右クリック（セカンダリタップ）すると「削除」オプションを含むコンテキストメニューが表示されなければならない（SHALL）。

#### Scenario: Right-click on novel folder at library root
- **WHEN** ユーザーがライブラリルートで小説フォルダを右クリックする
- **THEN** 「削除」オプションを含むコンテキストメニューが表示される

#### Scenario: No context menu inside novel folder
- **WHEN** ユーザーが小説フォルダ内のエピソードファイルを右クリックする
- **THEN** コンテキストメニューは表示されない

### Requirement: Delete confirmation dialog
「削除」メニュー項目を選択した際、小説タイトルを含む確認ダイアログが表示されなければならない（SHALL）。ダイアログには「削除」（赤色）と「キャンセル」ボタンを配置しなければならない（SHALL）。

#### Scenario: Show confirmation dialog
- **WHEN** ユーザーがコンテキストメニューの「削除」を選択する
- **THEN** 小説タイトルを含む確認ダイアログが表示される
- **AND** 「削除」ボタンが赤色で表示される
- **AND** 「キャンセル」ボタンが表示される

#### Scenario: Cancel deletion
- **WHEN** ユーザーが確認ダイアログで「キャンセル」を選択する
- **THEN** ダイアログが閉じる
- **AND** 小説データは変更されない

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

### Requirement: UI refresh after deletion
削除完了後、ファイルブラウザのUIが自動更新され、削除された小説がリストから消えなければならない（SHALL）。

#### Scenario: File browser updates after deletion
- **WHEN** 小説の削除が完了する
- **THEN** ファイルブラウザの小説一覧が自動的に更新される
- **AND** 削除された小説がリストに表示されない

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

