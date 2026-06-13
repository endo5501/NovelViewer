## Why

ブックマーク (`bookmarks`) と読書進捗 (`reading_progress`) は小説内ファイルを**絶対パス `file_path`** で永続化し、それを照合キーにしている。フォルダ管理機能で小説フォルダを移動・リネームすると、保存済みの絶対パスが即座にstaleになり、(1) 読書進捗の自動オープンが無言で外れ、(2) ブックマークジャンプが `File(filePath).existsSync()` 失敗で「ファイルが見つかりません」になる。`fix-novel-identity-consistency` で `novel_id` を葉名 (`folder_name`) に統一して移動耐性の土台を作った続きとして、ファイル単位の同一性も移動耐性のある **`novel_id` + `file_name`** に移す（TECH_DEBT_AUDIT F128。#3 で「後続change」と明示）。

## What Changes

- **BREAKING (DB schema)**: `novel_metadata.db` を version 7 → 8 に上げる。`bookmarks` と `reading_progress` から `file_path` 列を削除するワンショット移行を追加する。
  - `bookmarks`: テーブルを再作成し、UNIQUE制約を `(novel_id, file_path, line_number)` → `(novel_id, file_name, line_number)` に変更。`file_path` 列を削除。既存行は保持し、新UNIQUEで衝突する行は `INSERT OR IGNORE`（最古の `created_at` を残す）でdedupする。
  - `reading_progress`: テーブルを再作成し `file_path` 列を削除（PKは `novel_id` のまま、行内容を保持）。
- ブックマークの同一性・CRUDを `file_path` ベースから **`file_name` ベース**に変更する（`add` / `remove` / `exists` / `findByNovelAndFile` の照合キー、および呼び出し側 `bookmarkLineNumbersForFileProvider`・`toggleBookmark`）。
- 読書進捗の自動オープン照合を「保存済み絶対パスと `p.equals`」から「**現在のディレクトリ内の `file_name` 一致**」に変更する。
- 読み取り時にファイルの絶対パスを**現在の小説フォルダから再構成**する（ブックマークジャンプ `_openBookmark`：`File(filePath)` 直接参照を `join(現在の小説ディレクトリ, file_name)` に置換）。これによりブックマーク/進捗は小説フォルダの移動・リネーム後も追従する。
- `Bookmark` / `ReadingProgress` ドメインモデルおよび `*.toMap` / `fromMap` から `filePath` を除去する。

## Capabilities

### New Capabilities
（なし。既存capabilityの要件変更のみ）

### Modified Capabilities
- `bookmark-storage`: ブックマークの同一性キーを `file_path` から `file_name` へ変更。DB移行 v7→8（`bookmarks` 再作成・`file_path` 列削除・新UNIQUE・dedup）を追加。fresh install スキーマを更新。add/remove/exists/list/find の各要件を `file_name` 基準に改訂。
- `reading-progress`: `reading_progress` から `file_path` 列を削除（移行 v7→8）。自動オープンの照合を「現在ディレクトリ内の `file_name` 一致」に変更。upsert/read/auto-save/auto-open の各要件から絶対パス前提を除去し、フォルダ移動・リネーム耐性のシナリオを追加。

## Impact

- **コード**
  - `lib/features/novel_metadata_db/data/novel_database.dart`: `_databaseVersion` 7→8、`_onUpgrade` に v8 ステップ追加、`_onCreate` を v8 最終スキーマ生成に変更。既存の `_createBookmarksTable` / `_createReadingProgressTable`（v3/v6 アップグレード経路用・`file_path` 付き）は歴史的経路として温存し、v8 用の新スキーマ生成 + 移行関数を追加。
  - `lib/features/bookmark/domain/bookmark.dart`, `data/bookmark_repository.dart`, `providers/bookmark_providers.dart`, `presentation/bookmark_list_panel.dart`
  - `lib/features/reading_progress/domain/reading_progress.dart`, `data/reading_progress_repository.dart`, `providers/reading_progress_providers.dart`
- **テスト**: 上記リポジトリ/プロバイダ/ウィジェットの既存テスト改訂 + v7→8 移行テスト新規（F129「ブックマーク/進捗移行のカバレッジゼロ」を一部解消）。既存の v3→4 / v4→5 移行テストは引き続きグリーンであること。
- **データ移行**: 既存ユーザのDBは初回起動で v8 へ自動移行。`file_path` は失われるが、`novel_id` + `file_name` で再構成するため実害なし。ダウングレード非対応（一方向）。
- **依存/API**: 外部依存の追加なし。`folderDbKey` 等 per-folder DB には影響しない（対象はグローバル `novel_metadata.db` のみ）。
