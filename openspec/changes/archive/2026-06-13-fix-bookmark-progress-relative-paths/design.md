## Context

`bookmarks` / `reading_progress` は `novel_metadata.db`（現 version 7）に属する。両テーブルとも `file_name`（NOT NULL）と絶対 `file_path`（NOT NULL）を持つが、**照合に使うのは `file_path`** である:

- `bookmarks`: UNIQUE `(novel_id, file_path, line_number)`。`add`/`remove`/`exists`/`findByNovelAndFile` がすべて `file_path` で照合。`bookmark_list_panel._openBookmark` は `File(bookmark.filePath).existsSync()` で存在確認し、`p.dirname(filePath)` でディレクトリを設定。
- `reading_progress`: PK `novel_id`（1小説1行）。自動オープンは `p.equals(entry.path, progress.filePath)` でディレクトリ内ファイルと照合。

小説フォルダを移動・リネームすると絶対パスがstaleになり、進捗の自動オープンは無言で外れ、ブックマークジャンプは「ファイルが見つかりません」になる（F128）。

先行change `fix-novel-identity-consistency` で `novel_id` は葉名 (`folder_name`) に統一済みで、移動・リネームに対して安定している。`file_name`（エピソードのファイル名）もフォルダ移動・リネームでは変化しない。したがって `(novel_id, file_name)` は移動耐性のあるファイル同一性キーになる。

移行パターンの先例: 同DBには v3→v4 のテーブル再作成移行（`_migrateBookmarksAddLineNumber`）と v4→v5 の大規模再構成（`_migrateWordSummariesToSnapshots`、`IF NOT EXISTS`/`DROP IF EXISTS` による再実行耐性付き）がある。本changeはこの様式に倣う。

## Goals / Non-Goals

**Goals:**
- ブックマーク・読書進捗が小説フォルダの移動・リネーム後も追従する。
- DBに絶対パスを永続化しない（`file_path` 列を両テーブルから削除し、stale化しうる状態クラスを根絶する）。
- 既存ユーザのブックマーク・進捗を初回起動時の自動移行で保持する。
- v7→8 移行テストを追加し、移行カバレッジ（F129）を一部埋める。

**Non-Goals:**
- per-folder DB（`episode_cache.db` / `tts_audio.db` 等）の同種問題は対象外（対象はグローバル `novel_metadata.db` のみ）。
- DBハンドルのライフサイクル/レース（F108/F124/F125）は別change。
- ファイル単体のリネーム（フォルダではなく `001_x.txt` 自体の改名）への追従は対象外（ダウンロードの採番変更はF104の領域）。
- ダウングレード（v8→v7）対応は行わない（一方向移行）。

## Decisions

### D1. 絶対パスは保存せず、読み取り時に現在の小説フォルダから再構成する（列を残さず削除）

照合キーを `file_name` に切り替えるだけで `file_path` 列を温存する案も検討したが、stale化しうる絶対パス列が残ると「Why に書いた不具合の原因がDBに残置される」状態になり、将来の誤用（再び `file_path` を読む実装）を招く。監査F128の意図も「絶対パス保存をやめる」である。よって **`file_path` 列を両テーブルから削除**し、絶対パスが必要な箇所は読み取り時に再構成する。

- **読書進捗の自動オープン**: 自動オープンは元々「現在ディレクトリ `next` の `directoryContentsProvider` 内から一致ファイルを探す」処理。照合を `p.equals(entry.path, progress.filePath)` から **`entry.name == progress.fileName`**（パス区切り正規化のため basename 比較）に変更すれば、現在地のファイル一覧から探すので絶対パス不要・移動耐性あり。
- **ブックマークジャンプ** (`_openBookmark`): ブックマークパネルは常に「現在の小説」のブックマークを表示する（`bookmarksForNovelProvider(currentNovelId)`）。エピソードは小説フォルダ直下にフラットに配置されるため、対象ファイルの絶対パスは **`p.join(現在の小説ディレクトリ, bookmark.fileName)`** で再構成できる。`currentDirectoryProvider` が現在の小説フォルダを指すこと（パネル表示の前提）を利用する。

*代替案*: `novel_id`（=folder_name）から小説フォルダの絶対パスをライブラリツリー走査で逆引きする汎用ヘルパー。ネスト対応で再利用性は高いが、id→path 走査はコスト高で、消費箇所はいずれも「現在の小説コンテキスト」を持つため過剰。採用しない。

### D2. v7→8 移行はテーブル再作成方式（既存 v3→v4 様式の踏襲）

SQLite は列削除・UNIQUE制約変更を直接 `ALTER` できない（古いSQLiteでは `DROP COLUMN` 非対応）。`_migrateBookmarksAddLineNumber` と同じ **rename → 新スキーマ create → INSERT SELECT → drop old** 方式を用いる。

- `bookmarks`: 新UNIQUE `(novel_id, file_name, line_number)`。`file_path` を落とすと旧行で `(novel_id, file_name, line_number)` が衝突しうるため、`INSERT OR IGNORE` + `ORDER BY created_at ASC`（または `id ASC`）で**最古を残す**dedupにする。
- `reading_progress`: PKは `novel_id` のまま。`file_path` を除いた列で再作成し全行コピー（PK衝突は元々ないので単純コピー）。
- 再実行耐性: sqflite は `user_version` のbumpを `_onUpgrade` 成功後に行うため、移行途中クラッシュ時は次回再実行される。`_migrateWordSummariesToSnapshots` に倣い、中間テーブルへの `CREATE TABLE IF NOT EXISTS` / `DROP TABLE IF EXISTS` で再実行を安全にする。

### D3. `_onCreate` と歴史的アップグレード経路の分離

`_onCreate`（fresh install）は **v8 最終スキーマ**を直接生成する。一方、`_createBookmarksTable` / `_createReadingProgressTable` は v3/v6 アップグレード経路および v3→v4 移行が依存する**旧スキーマ（`file_path` 付き）**を生成し続ける必要がある。`_createV5WordSummariesTable` と `_createLegacyV2WordSummariesTable` が併存する既存パターンと同じく、v8用の新スキーマ生成関数（例: `_createBookmarksTableV8` / `_createReadingProgressTableV8`）を別途追加し、`_onCreate` はそれらを呼ぶ。v8移行関数は旧スキーマ（`file_path` 付き）を v8 スキーマへ変換する。

### D4. ドメインモデルから `filePath` を除去

`Bookmark` / `ReadingProgress` から `filePath` フィールドと `toMap`/`fromMap` の対応キーを削除する。呼び出し側（`toggleBookmark`・`_deleteBookmark`・`_openBookmark`・`bookmarkLineNumbersForFileProvider`・auto-save の upsert）を `file_name` 受け渡しに変更する。リポジトリAPIの引数も `filePath` → `fileName` に置換する。

## Risks / Trade-offs

- **既存ブックマークの dedup で件数が減る** → 旧データで `(novel_id, file_name, line_number)` が重複していたのは「同名ファイルが別パスに存在」した異常系のみ（葉名統一済みの現状ではほぼ発生しない）。最古を残すことでユーザの最初のブックマークを保持。移行ログにdedup件数を残して観測可能にする。
- **ブックマーク再構成が「現在の小説ディレクトリ」前提に依存** → パネルが現在小説のブックマークしか表示しない不変条件に依存する。万一ディレクトリが小説フォルダでない場合に備え、再構成後も `File(...).existsSync()` の存在確認 + 既存の `bookmark_fileNotFound` snackbar を維持する（フェイルセーフ）。
- **一方向移行（ダウングレード不可）** → `file_path` を落とすため v8→v7 でビルドを戻すと進捗/ブックマークが読めない。リリースノートに記載。実害は小さい（再構成可能な情報のみ喪失）。
- **移行途中クラッシュ** → D2 の再実行耐性（IF NOT EXISTS / DROP IF EXISTS）で緩和。`user_version` 後bumpにより自動再試行。
- **TDD順序の逸脱リスク** → 先に v7 シードDBを用意して現挙動（移行前=stale化で外れる）を固定するテストから書き、移行・ロジック変更で緑にする。

## Migration Plan

1. v7 状態のDB（`file_path` 付き bookmarks/reading_progress に数行シード）に対する v8 移行テストを先に作成（red）。
2. `_databaseVersion` を 8 に上げ、`_onUpgrade` に `oldVersion < 8` ステップ、`_onCreate` を v8 スキーマ化、移行関数を実装（green）。
3. リポジトリ/ドメイン/プロバイダ/ウィジェットを `file_name` ベースへ移行（既存テスト改訂しつつ）。
4. v3→4 / v4→5 / v5→6 / v6→7 の既存移行テストが緑のままであることを確認（フルチェーン昇格も確認）。
5. ロールバック: 移行は一方向。問題時は前バージョンのインストーラに戻すが `file_path` は復元されない旨を文書化。

## Resolved Questions

- **dedup の保持ルール**: 「最古（created_at ASC）を残す」で確定。ユーザが最初に付けたブックマークを保持する。
- **フルチェーン昇格テスト**: v1→v8 のフルチェーン昇格テストを本changeに**含める**（F129のさらなる解消）。v7→8 単体テストと併せて必須とする。
