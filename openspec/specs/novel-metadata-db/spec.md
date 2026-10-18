## Purpose

Persist non-reproducible novel metadata (titles, library entries, bookmarks, word summaries) in a SQLite database whose corruption must surface to the user rather than be silently reset.
## Requirements
### Requirement: Database initialization
The system SHALL initialize a SQLite database on application startup to manage novel metadata. On Windows, the database file SHALL be placed in the same directory as the exe file. On iOS, the database file SHALL be placed in the application support directory, NOT in the documents directory, because the documents directory is exposed to the Files app and this database holds non-reproducible data that is deliberately not auto-recovered on corruption. On macOS/Linux, the system SHALL use the default `getDatabasesPath()` location.

The platform-to-location mapping SHALL be expressed as a pure function that takes the platform flags as parameters, so every branch is testable without `dart:io`.

#### Scenario: First launch creates database
- **WHEN** the application starts for the first time and no database file exists
- **THEN** the system creates a SQLite database file with the novels table schema

#### Scenario: Subsequent launch uses existing database
- **WHEN** the application starts and the database file already exists
- **THEN** the system opens the existing database without data loss

#### Scenario: Windows database location
- **WHEN** the application starts on Windows
- **THEN** the database file SHALL be created at `<exe_directory>/novel_metadata.db`

#### Scenario: macOS database location unchanged
- **WHEN** the application starts on macOS
- **THEN** the database file SHALL be created in the `getDatabasesPath()` directory (existing behavior)

#### Scenario: iOS database location
- **WHEN** the application starts on iOS
- **THEN** the database file SHALL be created in the application support directory

#### Scenario: iOS database is not exposed to the Files app
- **WHEN** the application has started on iOS and the Files app is opened
- **THEN** `novel_metadata.db` is not listed alongside the novel library

#### Scenario: Location resolution is testable without dart:io
- **WHEN** the location-resolving function is called with each combination of platform flags
- **THEN** it returns the executable-directory location for Windows, the application-support location for iOS, and the platform-default location otherwise

### Requirement: Novel metadata storage
The system SHALL store novel metadata in a `novels` table with the following fields: auto-increment ID, site type, novel ID, title, URL, folder name, episode count, downloaded timestamp, and updated timestamp. The system SHALL provide a method to delete a novel record by folder name. Deleting a novel record SHALL NOT cascade to `word_summaries`, `fact_cache`, or `bookmarks`, because those tables no longer live in `novel_metadata.db` (they are removed with the novel's folder via its `novel_data.db`).

#### Scenario: Novel metadata is registered after download
- **WHEN** a novel download completes successfully
- **THEN** a record is inserted into the novels table with the site type, novel ID, title, source URL, ID-based folder name, episode count, and current timestamp

#### Scenario: Duplicate novel download updates existing record
- **WHEN** a novel with the same site type and novel ID is downloaded again
- **THEN** the existing record is updated with the new title, episode count, and updated timestamp instead of creating a duplicate

#### Scenario: Delete novel by folder name
- **WHEN** NovelRepository.deleteByFolderName(folderName) is called
- **THEN** the novel record matching the given folder name is deleted from the novels table
- **AND** no `word_summaries` / `fact_cache` / `bookmarks` rows are touched in `novel_metadata.db` (those tables no longer exist there)

### Requirement: Novel metadata retrieval
The system SHALL provide methods to query novel metadata from the database.

#### Scenario: Retrieve all novels
- **WHEN** the file browser requests the novel list
- **THEN** the system returns all novel records from the database ordered by title

#### Scenario: Retrieve novel by folder name
- **WHEN** the system needs to resolve a folder name to a novel title
- **THEN** the system returns the novel record matching the given folder name, or null if not found

#### Scenario: Retrieve novel by site type and novel ID
- **WHEN** the system checks if a novel already exists before download
- **THEN** the system returns the novel record matching the given site type and novel ID, or null if not found

### Requirement: ID-based folder naming
The system SHALL use the format `{site_type}_{novel_id}` for novel storage folders.

#### Scenario: Narou novel folder naming
- **WHEN** a novel is downloaded from narou with ncode `n1234ab`
- **THEN** the folder name SHALL be `narou_n1234ab`

#### Scenario: Kakuyomu novel folder naming
- **WHEN** a novel is downloaded from kakuyomu with work ID `16816452220917939820`
- **THEN** the folder name SHALL be `kakuyomu_16816452220917939820`

### Requirement: Novel ID extraction interface
Each site parser SHALL provide a method to extract the site-specific novel ID from a URL and a property to identify the site type.

#### Scenario: Extract narou novel ID from URL
- **WHEN** the URL `https://ncode.syosetu.com/n1234ab/` is provided to the narou parser
- **THEN** the extracted novel ID is `n1234ab`

#### Scenario: Extract kakuyomu novel ID from URL
- **WHEN** the URL `https://kakuyomu.jp/works/16816452220917939820` is provided to the kakuyomu parser
- **THEN** the extracted novel ID is `16816452220917939820`

#### Scenario: Site type identification
- **WHEN** the site type is queried from a parser
- **THEN** the narou parser returns `narou` and the kakuyomu parser returns `kakuyomu`

### Requirement: Update novel title by folder name
NovelRepositoryはフォルダ名を指定してタイトルのみを更新するメソッドを提供しなければならない（SHALL）。

#### Scenario: Update title for existing novel
- **WHEN** NovelRepository.updateTitle(folderName, newTitle)が呼び出される
- **AND** 指定されたfolder_nameのレコードが存在する
- **THEN** 該当レコードのtitleフィールドが新しいタイトルに更新される
- **AND** updated_atフィールドが現在日時に更新される

#### Scenario: Update title for non-existent novel
- **WHEN** NovelRepository.updateTitle(folderName, newTitle)が呼び出される
- **AND** 指定されたfolder_nameのレコードが存在しない
- **THEN** 例外がスローされる

### Requirement: Metadata database preserves data on open failure
The novel metadata database (`novel_metadata.db`) SHALL NOT be automatically deleted or recreated when its open operation fails. Failures SHALL be logged at WARNING level via `Logger('novel_metadata_db')` and rethrown so that the caller (typically application startup) becomes aware of the inconsistency. This requirement reflects that novel metadata (titles, library entries, reading progress) is non-reproducible user data, distinct from the reproducible local-folder databases (TTS audio, dictionary, episode cache). The per-folder `novel_data.db`, which now holds bookmarks, applies the same preservation contract on its own side.

#### Scenario: Open failure does not delete the database
- **WHEN** `NovelDatabase` calls the shared open helper and the database file is corrupt
- **THEN** a WARNING-level `LogRecord` is emitted on `Logger('novel_metadata_db')`, the original exception is rethrown, and the database file remains on disk so the user can attempt manual recovery or contact support

#### Scenario: Helper invocation uses deleteOnFailure=false
- **WHEN** `NovelDatabase` invokes the shared `openOrResetDatabase` helper
- **THEN** the call passes `deleteOnFailure: false`, distinguishing it from `TtsAudioDatabase`, `TtsDictionaryDatabase`, and `EpisodeCacheDatabase`

### Requirement: v8→v9 migrates then drops per-novel tables
The system SHALL upgrade `novel_metadata.db` to schema version 9. The v8→v9 `onUpgrade` SHALL, within its transaction, copy the `word_summaries`, `fact_cache`, and `bookmarks` rows into each novel's `novel_data.db` (idempotent upsert) and then, only after all extant folders are copied, drop those three tables. The `novels` and `reading_progress` tables SHALL be retained. The `user_version` SHALL be the sole completion flag: it is committed to 9 only when the `onUpgrade` transaction succeeds, so an interrupted migration rolls back to `user_version=8` and resumes on the next launch without data loss.

#### Scenario: Migrated tables are dropped at the end of the v8→v9 upgrade
- **WHEN** the application starts with `novel_metadata.db` at `user_version=8` and the v8→v9 `onUpgrade` copies every extant folder's rows successfully
- **THEN** `word_summaries`, `fact_cache`, and `bookmarks` SHALL be dropped as the final step
- **AND** the `novels` and `reading_progress` tables SHALL remain intact
- **AND** `user_version` SHALL be committed to 9

#### Scenario: Interrupted upgrade rolls back and resumes
- **WHEN** the v8→v9 `onUpgrade` is interrupted before completing
- **THEN** the `novel_metadata.db` transaction SHALL roll back, leaving `user_version=8` and the three global tables intact
- **AND** the next launch SHALL re-run the v8→v9 `onUpgrade`, with already-copied rows deduplicated by upsert

### Requirement: v10→v11 で参照元関係のテーブルを追加する

システムは、`novel_metadata.db` をスキーマバージョン 11 に上げなければならない（SHALL）。v10→v11 の昇格では、参照元関係を保存するテーブルを作成しなければならない（SHALL）。このテーブルは子と親の `folder_name` の組を保持し、同じ組が重複しない一意性を持つ。

既存のテーブル（`novels`、`reading_progress` など）とその行には、一切手を触れてはならない（SHALL NOT）。新規作成と昇格は、同じテーブル定義を経由しなければならない（SHALL）。昇格後のスキーマは、新規作成した v11 のスキーマと一致しなければならない（SHALL）。

#### Scenario: v10 のDBが昇格される
- **WHEN** `user_version=10` の `novel_metadata.db` でアプリを起動する
- **THEN** 参照元関係のテーブルが作成され、`user_version` は 11 になる
- **AND** `novels` と `reading_progress` の行はすべて保持される

#### Scenario: 昇格後のスキーマが新規作成と一致する
- **WHEN** v10 から昇格した DB と、新規作成した v11 の DB のスキーマを比較する
- **THEN** 参照元関係のテーブルの定義と一意インデックスが一致する

#### Scenario: 同じ組は重複しない
- **WHEN** 同じ子と親の組を2回保存しようとする
- **THEN** テーブルには1行だけが存在する

### Requirement: スキーマバージョン 12 で同期用のテーブルを追加する
システムは、`novel_metadata.db` をスキーマバージョン 12 に上げなければならない（SHALL）。v11→v12 の昇格では、進捗の同期に使う次の 3 つのテーブルを作成しなければならない（SHALL）。
- 他の端末から受け取った記録: 端末 ID と小説 ID の組で一意。端末名、実効エピソード番号、ファイル名、本文位置、本文ハッシュ、位置が動いた時刻を持つ
- 前回送信した自分の記録: 小説 ID で一意。列は上と同じ（端末 ID と端末名を除く）
- 確認済みの記録: 小説 ID で一意。確認した記録の、位置が動いた時刻を持つ

既存のテーブル（`novels`、`reading_progress` など）とその行には、一切手を触れてはならない（SHALL NOT）。新規作成と昇格は、同じテーブル定義を経由しなければならない（SHALL）。昇格後のスキーマは、新規作成した v12 のスキーマと一致しなければならない（SHALL）。

#### Scenario: v11 の DB が昇格される
- **WHEN** `user_version=11` の `novel_metadata.db` でアプリを起動する
- **THEN** 同期用の 3 つのテーブルが作成され、`user_version` は 12 になる
- **AND** `novels`、`reading_progress`、参照元関係のテーブルの行はすべて保持される

#### Scenario: 昇格後のスキーマが新規作成と一致する
- **WHEN** v11 から昇格した DB と、新規作成した v12 の DB のスキーマを比較する
- **THEN** 同期用の 3 つのテーブルの定義と一意性の制約が一致する

#### Scenario: 同じ端末と小説の組は重複しない
- **WHEN** 同じ端末 ID と小説 ID の組で、他の端末の記録を 2 回保存する
- **THEN** テーブルには 1 行だけが存在し、後から保存した内容になっている
