## ADDED Requirements

### Requirement: 小説フォルダ内データDBの提供
システムは、各小説フォルダ直下に単一の per-folder データベースファイル `novel_data.db` を設け、`word_summaries`・`fact_cache`・`bookmarks` の3テーブルを集約して保持しなければならない (SHALL)。このDBはフォルダ自身が小説の同一性を表すため、いずれのテーブルにも `folder_name` / `novel_id` カラムを持ってはならない (MUST NOT)。

新DBのスキーマは次のキー構成を持たなければならない (SHALL):
- `word_summaries`: 一意キー `(word, covered_up_to_episode)`
- `fact_cache`: 一意キー `(word, file_name)`
- `bookmarks`: 一意キー `(file_name, line_number)`（`line_number` の NULL 同士は同一とみなしてよい）

#### Scenario: フォルダ初回利用時にDBが作成される
- **WHEN** ある小説フォルダで初めて要約・fact・ブックマークのいずれかが書き込まれる
- **THEN** そのフォルダ直下に `novel_data.db` が作成される
- **AND** `word_summaries` / `fact_cache` / `bookmarks` の3テーブルが `folder_name`/`novel_id` カラムを持たない形で存在する

#### Scenario: 同一フォルダ内で行が一意に解決される
- **WHEN** `word_summaries` に同じ `(word, covered_up_to_episode)` の行を再書き込みする
- **THEN** ネイティブ upsert により行はその場で置換され、重複行は生じない

### Requirement: ハンドルレジストリとインターロックへの統合
`novel_data.db` のハンドルは `PerFolderDbRegistry` が一元管理しなければならない (SHALL)。レジストリは `episode_cache.db` / `tts_audio.db` / `tts_dictionary.db` と同様に、フォルダの移動・リネーム・空フォルダ削除・小説削除の各フローで `closeAll(folder)` を唯一の解放APIとして `novel_data.db` ハンドルを解放しなければならない (SHALL)。`novel_data.db` ラッパーは共有の接続ゲート（`database-connection-interlock`）契約に従わなければならない (SHALL)。ダウンロード専用の `closeEpisodeCache` は `novel_data.db` ハンドルを閉じてはならない (MUST NOT)。

#### Scenario: フォルダ移動前にハンドルが解放される
- **WHEN** 小説フォルダの移動・リネーム・削除が行われる
- **THEN** `closeAll(folder)` を経由して `novel_data.db` の `close()` 完了を待ってからファイルシステム操作が実行される

#### Scenario: ダウンロードフローはデータDBを閉じない
- **WHEN** ダウンロードフローが `closeEpisodeCache(folder)` を呼ぶ
- **THEN** `episode_cache.db` のみが閉じられ、`novel_data.db` のハンドルは閉じられない

### Requirement: open 失敗時にデータを保全する
`novel_data.db` は再現可能データ（要約・fact）に加え非再現データ（ブックマーク）を保持するため、open 失敗時に自動削除・再作成してはならない (MUST NOT)。失敗は `Logger` 経由で WARNING レベルに記録し、元の例外を rethrow してユーザーに不整合を気づかせなければならない (SHALL)。共有 open ヘルパには `deleteOnFailure: false` を渡さなければならない (SHALL)。

#### Scenario: 破損時にファイルを削除しない
- **WHEN** `novel_data.db` の open が破損により失敗する
- **THEN** WARNING ログが出力され、元の例外が rethrow され、ファイルはディスク上に残る

### Requirement: グローバルからの初回データ移行
システムは、既存ユーザーの `novel_metadata.db` 内 `word_summaries`・`fact_cache`・`bookmarks` の各行を、対応する小説フォルダの `novel_data.db` へ移送しなければならない (SHALL)。移行は `novel_metadata.db` の v8→v9 `onUpgrade` の中で実行し、ライブラリルート（および各フォルダの `novel_data.db` への書き込み手段）を注入依存として受け取らなければならない (SHALL)。移行の完了は `novel_metadata.db` の `user_version` を唯一のフラグとし、別途の完了マーカーを設けてはならない (MUST NOT)。各フォルダへのコピーは冪等（upsert）でなければならず (SHALL)、再実行で重複や二重挿入を生じてはならない (MUST NOT)。グローバル3テーブルの drop は全 extant フォルダのコピー成功後の最終段でのみ実行しなければならない (SHALL)。`reading_progress` は移行対象に含めてはならない (MUST NOT)。

#### Scenario: 既存の要約・fact・ブックマークがフォルダDBへ移る
- **WHEN** `user_version=8` の `novel_metadata.db` で起動し、グローバルに3テーブルの行が存在する
- **THEN** v8→v9 `onUpgrade` 内で各行が `novels` の対応フォルダの `novel_data.db` へ upsert でコピーされる
- **AND** 全 extant フォルダのコピー成功後にグローバルの3テーブルが drop され、`user_version` が 9 にコミットされる

#### Scenario: 移行が途中失敗しても再開できる
- **WHEN** `onUpgrade(8→9)` の途中でアプリがクラッシュする
- **THEN** `novel_metadata.db` のトランザクションがロールバックされ `user_version` は 8 のまま残る
- **AND** 次回起動で `onUpgrade(8→9)` が再実行され、既に移送済みの行は upsert により二重挿入されない

#### Scenario: 存在しないフォルダの孤児行は破棄される
- **WHEN** グローバルに、ディスク上に存在しないフォルダ名の行が残っている
- **THEN** その行は破棄され、破棄件数が WARNING ログに記録される

#### Scenario: reading_progress は移行されない
- **WHEN** v8→v9 移行が実行される
- **THEN** `reading_progress` テーブルには一切手を触れず、グローバルに残る
