## Why

現在、ユーザーが小説を読んだあとアプリを閉じて再度同じ小説を開くと、どこまで読んだかは手動しおりかユーザーの記憶に頼るしかなく、続きを探す手間が大きい。各小説ごとに「最後に開いていたファイル(章)」をアプリが暗黙的に記憶し、その小説フォルダに進入したときに自動でそのファイルを開けるようにする。

## What Changes

- 新規 SQLite テーブル `reading_progress` を `novel_metadata.db` に追加し、小説1件につき「最後に開いていたファイル」を 1 レコードだけ保持する (`novel_id` を PRIMARY KEY)。
- `novel_metadata.db` のスキーマバージョンを 4 → 5 に上げる。既存環境はマイグレーションで `reading_progress` テーブルを追加、新規環境は v5 で直接作成。
- ユーザーがファイルを選択して開いたタイミング(`selectedFileProvider` が non-null の値に変化した時)に、該当小説の `reading_progress` 行を upsert する。
- ユーザーがライブラリルート直下の小説フォルダに「進入した瞬間」のワンショットで、その小説の最終ファイルを自動オープンする(ライブラリルートでは何もしない、進入後にユーザーが別ファイルを開いたあとは介入しない)。
- 記録されたファイルが現存しない(refresh で番号体系が変わった、ファイル削除など)場合は黙ってフォールバック(自動オープンを行わず通常表示)。
- 小説削除時(`NovelRepository.deleteByFolderName`)に、対応する `reading_progress` 行も削除する。
- 行/スクロール位置の復元は **本変更のスコープ外**。

## Capabilities

### New Capabilities
- `reading-progress`: 小説ごとの最終閲覧ファイルを永続化し、小説フォルダ進入時に自動オープンを 1 度だけ発火させる機構。SQLite テーブル定義、CRUD API、進入時の復帰トリガ、ファイル切替時の自動保存を含む。

### Modified Capabilities
- `novel-delete`: 小説削除時に `reading_progress` の該当行も削除する要件を追加する。

(`novel-metadata-db` 側のスキーマバージョン管理は、各 capability spec が自分のテーブルに対する migration を宣言する既存方針 (`bookmark-storage` が v3→v4 を保有しているのと同様) に従い、reading-progress 側で v4→v5 を所有する。)

## Impact

- 影響コード:
  - `lib/features/novel_metadata_db/data/novel_database.dart` (マイグレーション v4→v5)
  - `lib/features/novel_delete/data/novel_delete_service.dart` (削除時の連鎖)
  - `lib/features/file_browser/providers/file_browser_providers.dart` (フォルダ進入の発火点)
  - `lib/features/bookmark/providers/bookmark_providers.dart` 周辺の `currentNovelIdProvider` を再利用
  - 新規追加: `lib/features/reading_progress/` 配下 (repository / providers)
- 影響データ:
  - `novel_metadata.db` のスキーマ v5 化(下位バージョンへの自動ダウングレードはサポートしない、これは既存方針と同じ)
- 影響仕様:
  - `novel-metadata-db` spec 更新、`novel-delete` spec 更新、`reading-progress` spec 新規。
- 依存関係: 既存パッケージのみ(sqflite)。新規依存なし。
