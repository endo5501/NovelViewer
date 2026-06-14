## 1. テストインフラ（逐次応答モック）

- [ ] 1.1 `test/features/text_download/helpers/download_test_helpers.dart` に、同一URLへのリクエスト回数に応じて応答を切り替えられる逐次応答モック（例: `sequencedClient` / `FakeRoute` のシーケンス対応）を追加し、`requestLog` で呼び出し回数を検証できるようにする
- [ ] 1.2 503→200、503連発、404単発、TimeoutException→200 を表現できることを最小テストで確認する

## 2. リトライのテスト作成（失敗を先に確認＝TDD）

- [ ] 2.1 エピソード本文: 503→200 で再試行され保存・キャッシュ登録され `failedCount==0`、リクエストが2回発行されることを検証するテストを追加（先に失敗を確認）
- [ ] 2.2 後続目次ページ: 503→200 で再試行され `indexTruncated==false`、エピソードが欠落しないことを検証するテストを追加
- [ ] 2.3 エピソード本文: 5xx を `maxRetries+1` 回連発 → `failedCount++` かつ WARNING ログ、次エピソードへ継続を検証
- [ ] 2.4 後続目次ページ: 5xx を `maxRetries+1` 回連発 → `indexTruncated==true`、それまでのエピソードは保持を検証
- [ ] 2.5 1ページ目目次: 5xx を `maxRetries+1` 回連発 → 例外が `downloadNovel` から伝播し、空フォルダが残らないことを検証
- [ ] 2.6 4xx（404）はリトライされず、リクエストがちょうど1回であることを検証
- [ ] 2.7 TimeoutException→200 で再試行して成功することを検証
- [ ] 2.8 バックオフ待機中／再試行直前のキャンセルが、`failedCount` や `indexTruncated` ではなくキャンセルとして扱われることを検証
- [ ] 2.9 `maxRetries` / `retryBaseDelay` がコンストラクタで注入でき、テストが実時間待機なし（`retryBaseDelay` 極小値）で完結することを確認

## 3. 実装（テストをパスさせる）

- [ ] 3.1 `DownloadService` に `int maxRetries`（既定 2）と `Duration retryBaseDelay`（既定 500ms）のコンストラクタ引数を追加
- [ ] 3.2 `_fetchPageResponse` に `CancellationToken? cancelToken` 引数を追加し、3つの呼び出し元（`downloadNovel`／`_collectPagedIndex`／`_downloadEpisodes`）から現在の token を渡す。`fetchPage` 等 token 非保持経路は `null`
- [ ] 3.3 `_fetchPageResponse` をリトライループ化: 200 は即返却、5xx は上限まで指数バックオフで再試行・使い切りで `HttpException`、4xx 等は即 `HttpException`、`TimeoutException` は上限まで再試行・使い切りで rethrow、その他例外（`ClientException` 等）は非リトライで伝播
- [ ] 3.4 `_backoff` ヘルパー（`retryBaseDelay * 2^(attempt-1)`）を実装し、待機前後・ループ先頭で `throwIfCancelled()` を呼ぶ
- [ ] 3.5 既存のキャンセル／truncation／failedCount 契約が壊れていないことを既存テスト（`download_cancellation_test` / `index_truncated_test` / `request_timeout_test` / `empty_parse_failure_test` 等）で確認

## 4. 最終確認

- [ ] 4.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 4.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 4.3 `fvm flutter analyze`でリントを実行
- [ ] 4.4 `fvm flutter test`でテストを実行
