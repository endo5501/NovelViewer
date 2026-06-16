## 1. 新DBラッパー `novel_data.db` とスキーマ

- [x] 1.1 `novel_data.db` スキーマ（v1: `word_summaries(word, covered_up_to_episode, ...)` / `fact_cache(word, file_name, ...)` / `bookmarks(file_name, line_number, ...)`、`folder_name`/`novel_id` カラム無し、各一意インデックス）のテストを先に作成（テーブル定義・一意制約・upsert）
- [x] 1.2 テストの失敗を確認し、テストをコミット
- [x] 1.3 `NovelDataDatabase` ラッパーを実装（共有 `DbConnectionGate` 経由、`openOrResetDatabase` に `deleteOnFailure: false`、フォルダ配下に配置）
- [x] 1.4 open 失敗時にファイルを保全し WARNING ログ＋rethrow するテストを作成→失敗確認→実装
- [x] 1.5 1.1〜1.4 のテストを全てパスさせる

## 2. PerFolderDbRegistry への統合

- [x] 2.1 `novelData(folder)` 追加、`closeAll` / `releaseInBackground` / `disposeAll` が `novel_data.db` ハンドルを含むこと、`closeEpisodeCache` は含まないことを検証するテストを作成→失敗確認
- [x] 2.2 `PerFolderDbRegistry` に4本目ハンドルを実装し、close 振り付けに組み込む
- [x] 2.3 thin-view provider（`per_folder_db_registry_provider` 周辺）に `novel_data.db` ビューを追加し、解放＋provider無効化ヘルパーに束ねる
- [x] 2.4 `database-connection-interlock` の契約（in-flight open 共有・close 相互排他・close 中取得の明示エラー・失敗の非キャッシュ）を新ラッパーが満たすテストを作成→実装→パス

## 3. リポジトリのフォルダDBハンドル化

- [x] 3.1 `LlmSummaryRepository` をフォルダDBハンドル受け取り＋キー `(word, covered_up_to_episode)`（`folderName` 引数除去）へ変更するテストを作成→失敗確認→実装
- [x] 3.2 `FactCacheRepository` をフォルダDBハンドル受け取り＋キー `(word, file_name)`（`folderName` 引数除去）へ変更するテストを作成→失敗確認→実装
- [x] 3.3 `BookmarkRepository` をフォルダDBハンドル受け取り＋キー `(file_name, line_number)`（`novel_id` 引数除去）へ変更するテストを作成→失敗確認→実装
- [x] 3.4 `ReadingProgressRepository` は据え置き（グローバル維持）であることを確認（変更しない）
- [x] 3.5 各 Riverpod provider を新ラッパー／新シグネチャに差し替え、解析ランナー・hover popup・history UI・ブックマークUI の呼び出し側を更新

## 4. v8→v9 onUpgrade 内データ移行

- [x] 4.1 v8→v9 `onUpgrade` 移行のテストを作成（各フォルダ `novel_data.db` への upsert コピー冪等・全コピー成功後の3テーブル drop・途中失敗で `user_version=8` のまま再実行可・孤児行破棄＋WARNINGログ・`reading_progress` 不可触）→失敗確認
- [x] 4.2 ライブラリルート（＋フォルダDB書き込み手段）の注入依存を `NovelDatabaseSnapshotResolver` と同様の要領で追加（`NovelDataMigrator`）
- [x] 4.3 v8→v9 `onUpgrade` を実装（コピー → 全成功後に drop、`user_version` を唯一の完了フラグとする）
- [x] 4.4 4.1 のテストを全てパスさせる

## 5. novel_metadata.db スキーマ v9 化

- [x] 5.1 fresh install で v9 スキーマ（`word_summaries`/`fact_cache`/`bookmarks` 無し、`novels`/`reading_progress` 有り）になることのテストを作成→失敗確認
- [x] 5.2 `NovelDatabase` を v9 に更新し、`createCurrentSchema` から3テーブルDDLを除去
- [x] 5.3 全マイグレーションチェーン（v4→…→v9）と fresh install のスキーマ忠実性テストを更新→パス

## 6. novel-delete の縮小

- [x] 6.1 `NovelDeleteService` が `novels`+`reading_progress` のみを単一トランザクションで削除し、要約/fact/bookmark の削除呼び出しを行わず、`novel_data.db` を含む4ハンドルを解放してからFS削除する、というテストを作成→失敗確認
- [x] 6.2 `NovelDeleteService` を実装変更（不要な repository 依存を除去、ハンドル解放対象に `novel_data.db` を追加）
- [x] 6.3 削除順序・原子性・FS失敗時のロールバック・孤児行非発生のテストをパスさせる

## 7. 移動・リネーム・切替フローの解放対象更新

- [ ] 7.1 移動・リネーム・空フォルダ削除・フォルダ切替で `novel_data.db` ハンドルが `closeAll`/`releaseInBackground` 経由で解放されることのテストを作成→失敗確認
- [ ] 7.2 `file_browser` / `novel_folder_management` の各フローを更新し、解放＋provider無効化ヘルパーを経由させる
- [ ] 7.3 バックグラウンドLLM解析の書き込みがフォルダ非アクティブ化時に永続化をスキップ/中断する保護のテスト→実装→パス

## 8. 最終確認

- [ ] 8.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 8.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 8.3 `fvm flutter analyze`でリントを実行
- [ ] 8.4 `fvm flutter test`でテストを実行
