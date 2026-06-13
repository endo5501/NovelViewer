## 1. DB移行テスト（先に失敗を確認 / TDD）

- [x] 1.1 v7状態のDB（`file_path`付き `bookmarks`/`reading_progress` に複数行シード）を作るテストヘルパーを用意（既存の移行テスト様式 `runMigrationForTesting`/v6移行テストを手本に）
- [x] 1.2 v7→8移行で `bookmarks` から `file_path` 列が消え、UNIQUEが `(novel_id, file_name, line_number)` になり、行（id/novel_id/file_name/line_number/created_at）が保持されることを検証するテストを追加（red）
- [x] 1.3 `(novel_id, file_name, line_number)` が衝突する旧行が最古 `created_at` を残してdedupされることを検証するテストを追加（red）
- [x] 1.4 v7→8移行で `reading_progress` から `file_path` 列が消え、`novel_id`/`file_name`/`updated_at` が保持されることを検証するテストを追加（red）
- [x] 1.5 fresh install が version 8・新スキーマ（両テーブルに `file_path` 無し）で作成されることを検証するテストを追加（red）

## 2. DBスキーマ・移行の実装

- [x] 2.1 `_databaseVersion` を 7 → 8 に更新
- [x] 2.2 v8最終スキーマ生成関数を追加（`_createBookmarksTableV8`: `file_path`無し・UNIQUE `(novel_id, file_name, line_number)` / `_createReadingProgressTableV8`: `file_path`無し）。既存 `_createBookmarksTable`・`_createReadingProgressTable`（`file_path`付き）はアップグレード経路用に温存
- [x] 2.3 `_onCreate` を v8 スキーマ生成関数を呼ぶよう変更
- [x] 2.4 `_onUpgrade` に `oldVersion < 8` ステップを追加し移行関数を呼ぶ
- [x] 2.5 v8移行関数を実装（create-new→`INSERT OR IGNORE ... ORDER BY created_at ASC`→drop old→rename、`DROP IF EXISTS`で再実行耐性、dedup件数をWARNログ出力）
- [x] 2.6 1章のテストが緑になることを確認

## 3. ドメイン・リポジトリの `file_name` 移行（TDD）

- [x] 3.1 `BookmarkRepository` のテストを `file_name` ベース（add/remove/exists/findByNovelAndFile）に改訂（red）
- [x] 3.2 `Bookmark` から `filePath` を除去（`toMap`/`fromMap` 含む）
- [x] 3.3 `BookmarkRepository` の add/remove/exists/findByNovelAndFile を `file_name` 引数・照合に変更（green）
- [x] 3.4 `ReadingProgressRepository` のテストを `file_name` ベース（upsert/findByNovelId）に改訂（red）
- [x] 3.5 `ReadingProgress` から `filePath` を除去（`toMap`/`fromMap` 含む）
- [x] 3.6 `ReadingProgressRepository.upsert`/`findByNovelId` を `file_name` のみに変更（green）

## 4. プロバイダ・UIの再構成ロジック（TDD）

- [x] 4.1 `bookmark_providers.dart`: `toggleBookmark`・`bookmarkLineNumbersForFileProvider` を `file_name`（`selectedFile.name`）ベースに変更
- [x] 4.2 `bookmark_list_panel._openBookmark` を「現在の小説ディレクトリ + `file_name` で絶対パス再構成 → `existsSync` フェイルセーフ → 既存 `bookmark_fileNotFound` snackbar」に変更。`_deleteBookmark` の `remove` も `file_name` 化
- [x] 4.3 移動/リネーム後にブックマークジャンプが追従し、ファイル不在時は従来の「見つかりません」を出すウィジェット/ロジックテストを追加（red→green）
- [x] 4.4 `reading_progress_providers.dart` の auto-save を `file_name` upsert に、auto-open の照合を `p.equals(entry.path, filePath)` → `entry.name == fileName`（basename比較）に変更
- [x] 4.5 移動/リネーム後に進捗の自動オープンが追従するシナリオ（reading-progress spec の新シナリオ）をテスト追加（red→green）

## 5. 回帰確認

- [x] 5.1 既存の v3→4 / v4→5 / v5→6 / v6→7 移行テストが緑のままであることを確認
- [x] 5.2 v1→v8 フルチェーン昇格テストを追加（各歴史版をシードして `NovelDatabase` 経由で開き、最終スキーマ・データ保持を検証。F129のさらなる解消）
- [x] 5.3 `bookmark-ui` / `bookmark-storage` / `reading-progress` 関連の既存テスト全体がグリーンであることを確認

## 6. 最終確認

- [x] 6.1 code-reviewスキルを使用してコードレビューを実施（auto-openのWindows大文字小文字一致を`p.equals`で復元、v8移行のDDL重複をcreate-helper再利用で解消＋dedup件数を`changes()`で算出。サブフォルダ前提のネスト指摘は「エピソードはフラット配置」前提で許容と判断）
- [x] 6.2 codexスキルを使用して現在開発中のコードレビューを実施（NULL行ブックマークの重複排除漏れを指摘→移行クエリで(novel_id,file_name,line_number)グループの最古保持に修正＋テスト追加。同名サブフォルダ/ネスト指摘はフラット配置前提で許容）
- [x] 6.3 `fvm flutter analyze`でリントを実行（No issues found）
- [x] 6.4 `fvm flutter test`でテストを実行（2006 passed）
- [x] 6.5 TECH_DEBT_AUDIT.md の F128 行と Top 5 #3 を「対応済み」に更新（F128はQuick wins対象外のため該当なし）
