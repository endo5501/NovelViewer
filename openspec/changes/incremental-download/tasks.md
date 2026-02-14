## 1. EpisodeCacheドメインモデル

- [ ] 1.1 `lib/features/episode_cache/domain/episode_cache.dart`に`EpisodeCache`モデルクラスを作成（url, episodeIndex, title, lastModified, downloadedAt フィールド）
- [ ] 1.2 `EpisodeCache`のテストを作成（fromMap, toMap の変換テスト）

## 2. EpisodeCacheDatabase

- [ ] 2.1 `lib/features/episode_cache/data/episode_cache_database.dart`に`EpisodeCacheDatabase`クラスを作成（小説フォルダパスを受け取り、`episode_cache.db`を開く/作成する）
- [ ] 2.2 `episode_cache`テーブルのスキーマ作成ロジックを実装（url TEXT PRIMARY KEY, episode_index INTEGER, title TEXT, last_modified TEXT, downloaded_at TEXT）
- [ ] 2.3 DB破損時のフォールバック処理を実装（破損ファイル削除→新規作成）
- [ ] 2.4 `EpisodeCacheDatabase`のテストを作成

## 3. EpisodeCacheRepository

- [ ] 3.1 `lib/features/episode_cache/data/episode_cache_repository.dart`に`EpisodeCacheRepository`クラスを作成
- [ ] 3.2 `upsert`メソッドを実装（エピソードキャッシュの挿入/更新）
- [ ] 3.3 `findByUrl`メソッドを実装（URLによる個別検索）
- [ ] 3.4 `getAllAsMap`メソッドを実装（全キャッシュレコードをURL→EpisodeCacheのMapで返す）
- [ ] 3.5 `EpisodeCacheRepository`のテストを作成

## 4. DownloadServiceへのHEADリクエスト追加

- [ ] 4.1 `DownloadService`に`fetchHead`メソッドを追加（URLにHEADリクエストを送信し、レスポンスヘッダを返す）
- [ ] 4.2 `fetchHead`のテストを作成（Last-Modifiedヘッダの取得、ヘッダなしの場合、リクエスト失敗時の処理）

## 5. DownloadServiceの差分ダウンロードロジック

- [ ] 5.1 `downloadNovel`メソッドに`EpisodeCacheRepository`を受け取るパラメータを追加
- [ ] 5.2 ダウンロードループにキャッシュ照合ロジックを追加（URLがキャッシュにない→ダウンロード、キャッシュにある→HEADリクエストで更新チェック）
- [ ] 5.3 HEADリクエストの`Last-Modified`比較ロジックを実装（新しい→ダウンロード、同じ/古い→スキップ、ヘッダなし→スキップ）
- [ ] 5.4 ダウンロード成功後にキャッシュDBへメタデータを保存する処理を追加
- [ ] 5.5 `DownloadResult`にスキップ数フィールドを追加
- [ ] 5.6 差分ダウンロードのテストを作成（新規エピソード、更新あり、更新なし、Last-Modifiedなし、HEADリクエスト失敗の各シナリオ）

## 6. DownloadState・DownloadNotifierの拡張

- [ ] 6.1 `DownloadState`に`skippedEpisodes`フィールドを追加
- [ ] 6.2 `DownloadNotifier`の`startDownload`メソッドで`EpisodeCacheRepository`の生成・注入を実装
- [ ] 6.3 プログレスコールバックにスキップ数を反映
- [ ] 6.4 ダウンロード完了後のDB close処理を追加

## 7. DownloadDialogのUI更新

- [ ] 7.1 ダウンロード進捗表示にスキップ件数を表示する（例:「5/100 (スキップ: 90件)」）
- [ ] 7.2 ダウンロード完了メッセージにスキップ件数を含める

## 8. 最終確認

- [ ] 8.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [ ] 8.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 8.3 `fvm flutter analyze`でリントを実行
- [ ] 8.4 `fvm flutter test`でテストを実行
