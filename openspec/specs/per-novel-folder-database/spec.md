# per-novel-folder-database Specification

## Purpose
TBD - created by archiving change migrate-per-novel-data-to-folder-db. Update Purpose after archive.
## Requirements

### Requirement: 小説フォルダ内データDBの提供
システムは、各小説フォルダ直下に単一の per-folder データベースファイル `novel_data.db` を設け、`word_summaries`・`fact_cache`・`bookmarks` の3テーブルを集約して保持しなければならない (SHALL)。このDBはフォルダ自身が小説の同一性を表すため、いずれのテーブルにも `folder_name` / `novel_id` カラムを持ってはならない (MUST NOT)。

新DBのスキーマは次のキー構成を持たなければならない (SHALL):
- `word_summaries`: 一意キー `(word, covered_up_to_episode)`
- `fact_cache`: 一意キー `(word, file_name, model_id)`
- `bookmarks`: 一意キー `(file_name, line_number)`（`line_number` の NULL 同士は同一とみなしてよい）

`fact_cache` の一意キーに `model_id` が含まれるのは、どのモデルが書いた事実かによって行を分けるためである。根拠と挙動は `llm-summary-fact-cache` が定める。

#### Scenario: フォルダ初回利用時にDBが作成される
- **WHEN** ある小説フォルダで初めて要約・fact・ブックマークのいずれかが書き込まれる
- **THEN** そのフォルダ直下に `novel_data.db` が作成される
- **AND** `word_summaries` / `fact_cache` / `bookmarks` の3テーブルが `folder_name`/`novel_id` カラムを持たない形で存在する

#### Scenario: 同一フォルダ内で行が一意に解決される
- **WHEN** `word_summaries` に同じ `(word, covered_up_to_episode)` の行を再書き込みする
- **THEN** ネイティブ upsert により行はその場で置換され、重複行は生じない

#### Scenario: モデルが異なる fact 行は別行として共存する
- **WHEN** `fact_cache` に同じ `(word, file_name)` で `model_id` の異なる行を書き込む
- **THEN** 一意キーが衝突せず、両方の行が共存する

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
システムは、既存ユーザーの `novel_metadata.db` 内 `word_summaries`・`bookmarks` の各行を、対応する小説フォルダの `novel_data.db` へ移送しなければならない (SHALL)。移行は `novel_metadata.db` の v8→v9 `onUpgrade` の中で実行し、ライブラリルート（および各フォルダの `novel_data.db` への書き込み手段）を注入依存として受け取らなければならない (SHALL)。移行の完了は `novel_metadata.db` の `user_version` を唯一のフラグとし、別途の完了マーカーを設けてはならない (MUST NOT)。各フォルダへのコピーは冪等（upsert）でなければならず (SHALL)、再実行で重複や二重挿入を生じてはならない (MUST NOT)。グローバル3テーブルの drop は全 extant フォルダのコピー成功後の最終段でのみ実行しなければならない (SHALL)。`reading_progress` は移行対象に含めてはならない (MUST NOT)。

グローバルの `fact_cache` 行はフォルダDBへ移送してはならない (MUST NOT)。移送元の行はどのモデルが抽出したか分からず、`llm-summary-fact-cache` により名乗りを持たない行は存在させないと定められている。名乗りのない行を作れば、どのクライアントからも引かれず upsert でも置換されない残骸になる。移送しない代わりに、その語の次回解析で再抽出される。グローバルの `fact_cache` テーブル自体は、他の2テーブルと同じ最終段で drop しなければならない (SHALL)。

#### Scenario: 既存の要約・ブックマークがフォルダDBへ移る
- **WHEN** `user_version=8` の `novel_metadata.db` で起動し、グローバルに3テーブルの行が存在する
- **THEN** v8→v9 `onUpgrade` 内で `word_summaries` と `bookmarks` の各行が `novels` の対応フォルダの `novel_data.db` へ upsert でコピーされる
- **AND** 全 extant フォルダのコピー成功後にグローバルの3テーブルが drop され、`user_version` が 9 にコミットされる

#### Scenario: グローバルの fact 行は移送されない
- **WHEN** グローバルの `fact_cache` に行が存在する状態で v8→v9 移行が実行される
- **THEN** フォルダDBの `fact_cache` に行は作られない
- **AND** グローバルの `fact_cache` テーブルは最終段で drop される

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

### Requirement: `novel_data.db` のスキーマバージョンと昇格経路

`novel_data.db` はスキーマバージョンを持ち、旧バージョンのファイルを開いたときは本番の昇格経路 (`onUpgrade`) を通して現行バージョンへ引き上げなければならない (SHALL)。昇格を経ずに旧スキーマのまま使用してはならない (MUST NOT)。

`fact_cache` にモデルの名乗り (`model_id`) を導入するバージョンでは、昇格は `fact_cache` テーブルを drop し、現行スキーマの DDL で作り直さなければならない (SHALL)。列追加 (`ALTER TABLE ADD COLUMN`) を用いてはならない (MUST NOT)。SQLite は NOT NULL 列の追加に DEFAULT 句を要求するため、列追加で昇格した DB は新規作成の DB とスキーマが食い違う。作り直せば両者は完全に一致し、`db-schema-test-fidelity` が排除しようとしているスキーマドリフトが生じない。

行の保存は不要である。`llm-summary-fact-cache` により、名乗りを持たない行は保持しないと定められているためである。`word_summaries` と `bookmarks` には一切手を触れてはならない (MUST NOT)。

現行スキーマの DDL は単一の正でなければならず (SHALL)、新規作成・昇格・テストフィクスチャのいずれもが同じ定義を経由しなければならない (SHALL)。現行スキーマで `novel_data.db` を作るすべての経路は、そのスキーマが実際に何番であるかを `user_version` に刻まなければならない (SHALL)。古い番号を刻めば、スキーマと刻印が食い違ったファイルが残る。

システムは、この実装が知らない新しいバージョンで書かれた `novel_data.db` を開くことを拒否しなければならない (SHALL)。sqflite は降格コールバックが未指定のとき何も実行せず、そのうえで要求されたバージョンを書き込むため、テーブルは新しい形のまま刻印だけが古くなる。その刻印を信じた実装は、テーブルにもう存在しない一意キーを指す upsert を投げ、書き込みのたびに失敗する。open を失敗させるほうが、起きたことを言い当てている。ファイルを削除してはならない (MUST NOT)。

#### Scenario: 旧バージョンのDBが昇格される
- **WHEN** `model_id` を持たない旧バージョンの `novel_data.db` を開く
- **THEN** 本番の昇格経路が走り、`fact_cache` が `model_id` を含む現行スキーマで作り直される

#### Scenario: 昇格後のスキーマが新規作成と一致する
- **WHEN** 旧バージョンから昇格した `novel_data.db` と、新規作成された `novel_data.db` のスキーマを比較する
- **THEN** `fact_cache` のテーブル定義と一意インデックスが両者で一致する

#### Scenario: 昇格は他のテーブルに触れない
- **WHEN** `word_summaries` と `bookmarks` に行がある旧バージョンの `novel_data.db` を昇格させる
- **THEN** 両テーブルの行はすべて保持される

#### Scenario: 知らないバージョンのDBは開けない
- **WHEN** この実装が理解するより新しいバージョンで書かれた `novel_data.db` を開こうとする
- **THEN** open は失敗し、ファイルの `user_version` は書き換えられない
- **AND** ファイルはディスク上に残る

#### Scenario: 移送が作るDBも現行バージョンで刻まれる
- **WHEN** v8→v9 移送が小説フォルダの `novel_data.db` を新規に作成する
- **THEN** そのファイルの `user_version` は現行スキーマのバージョンと一致する

#### Scenario: 昇格は名乗りのない fact 行を残さない
- **WHEN** `fact_cache` に行がある旧バージョンの `novel_data.db` を昇格させる
- **THEN** 昇格後の `fact_cache` に行は残らず、次回の解析で再抽出される
