## Why

`word_summaries`・`fact_cache`・`bookmarks` の3テーブルは、いずれも「特定の1小説」に属し、かつ全クエリが `folder_name` / `novel_id`(==`folder_name`) 単一小説キーでしか引かれない（複数小説をまたぐ横断クエリは存在せず、将来も予定がない）にもかかわらず、グローバルな `novel_metadata.db` に置かれている。このため、フォルダの削除・移動・バックアップとデータの整合をコード側で常に手当てする必要があり、孤児行（F107/F127）の温床になっている。一方で TTS音声・辞書・エピソードキャッシュは既にフォルダ内DBに置かれ「フォルダ可搬」になっている。本変更でこの非対称を解消し、per-novel データをフォルダと運命を共にさせる。

なお `reading_progress` は同じく per-novel データだが、**今後ライブラリ一覧で「各小説を何話まで読んだか」を横断バッチ表示する構想**があり、これは複数小説をまたぐ集約クエリになる。フォルダ分散すると全フォルダDBを開く必要が生じて性能が劣化するため、`reading_progress` は移動対象から除外し、グローバル `novel_metadata.db` に残す。

## What Changes

- 各小説フォルダ内に新しい per-folder DB ファイル（仮称 `novel_data.db`）を1個導入し、`word_summaries` / `fact_cache` / `bookmarks` の3テーブルをそこへ集約する。
- `reading_progress` は移動せず `novel_metadata.db` に残す（将来の横断バッチ表示のため）。
- 新DBではフォルダ自身が小説の同一性を表すため、冗長な `folder_name` / `novel_id` カラムを除去する（`word_summaries` のキーは `(word, covered_up_to_episode)`、`fact_cache` は `(word, file_name)`、`bookmarks` は `(file_name, line_number)` へ）。
- 新DBハンドルを `PerFolderDbRegistry` に4本目として組み込み、既存の close 振り付け（移動・リネーム・削除前の `closeAll` 経由解放、lock-bug 対策）に従わせる。共有の接続ゲート（`database-connection-interlock`）契約も適用する。
- `novel_metadata.db` を v8→v9 へ更新。v8→v9 `onUpgrade` の中で、移動対象3テーブルの行を各フォルダの `novel_data.db` へ移送（冪等 upsert）し、全フォルダ成功後に3テーブルを drop する。`user_version` を唯一の移行完了フラグとする。`novel_metadata.db` は `novels`（カタログ）＋ `reading_progress`（横断表示用）のみを持つ。
- **BREAKING**: `novel-delete` のカスケード削除を変更。移動した3テーブルをグローバルから消す処理は廃止し、フォルダ（＝`novel_data.db` ファイル）削除に吸収する。`novels` と `reading_progress` のグローバル削除（単一トランザクション）は維持する。孤児行（F107/F127）は原理的に発生しなくなる。
- バックグラウンドで走り得る LLM 解析の書き込みが、フォルダの移動・切替・削除に伴う close と競合しないことを保証する。

## Capabilities

### New Capabilities
- `per-novel-folder-database`: 各小説フォルダ内の新DB（`novel_data.db`）の責務 — 3テーブル（`word_summaries`/`fact_cache`/`bookmarks`）の集約スキーマ、フォルダ＝同一性に基づくカラム設計、スキーマ版管理、`PerFolderDbRegistry` への統合、グローバル `novel_metadata.db` からの初回データ移行。

### Modified Capabilities
- `novel-metadata-db`: 移動した3テーブルを保持しなくなり、`novels` カタログ＋ `reading_progress` のみを持つ。v9 で3テーブルを drop。non-reproducible user data に関する記述を更新する。
- `llm-summary-cache`: `word_summaries` の保存先をフォルダ内 `novel_data.db` に変更し、キーから `folder_name` を除去する。
- `llm-summary-fact-cache`: `fact_cache` の保存先をフォルダ内 `novel_data.db` に変更し、キーから `folder_name` を除去する。カスケード削除はフォルダ削除に吸収される。
- `bookmark-storage`: ブックマークの保存先をフォルダ内 `novel_data.db` に変更し、`novel_id` カラムを除去する。
- `novel-delete`: 移動した3テーブルのグローバル削除を廃止しフォルダ（DBファイル）削除に吸収する。`novels` と `reading_progress` のグローバル単一トランザクション削除は維持する。
- `novel-folder-management`: per-folder DBハンドルレジストリが管理する対象を3個から4個（`novel_data.db` を追加）に拡張する。移動・リネーム・削除フローの解放対象も更新する。
- `database-connection-interlock`: 新しい per-folder DBラッパーも共有の接続ゲート・インターロック契約に従う対象に含める。

## Impact

- **コード**:
  - 新規: フォルダ内DBラッパー（`novel_data.db`）とそのスキーマ/マイグレーション、`PerFolderDbRegistry` への4本目ハンドル統合。
  - 改修: `LlmSummaryRepository` / `FactCacheRepository` / `BookmarkRepository` をフォルダDBハンドル受け取りに変更（キーから `folder_name`/`novel_id` を除去）。`ReadingProgressRepository` は据え置き（グローバル維持）。
  - 改修: `NovelDatabase`（v9マイグレーションで3テーブル drop、`reading_progress` は残す）、`NovelDeleteService`（移動3テーブルのカスケード廃止、`novels`+`reading_progress` 削除は維持）、各 Riverpod provider（フォルダDBハンドルへ差し替え）。
  - 改修: 移動・リネーム・切替フロー（`file_browser` / `novel_folder_management`）で `novel_data.db` ハンドルも解放対象に。
- **データ**: 既存ユーザーの `novel_metadata.db` 内3テーブルを各フォルダの新DBへ移送。移行失敗時の安全性（非再現データの保護）に注意。
- **依存/システム**: 使用パッケージの追加は無し（既存 sqflite/ffi を踏襲）。Windows のファイルロック挙動（close 完了待ち）に依存する箇所が増える。
