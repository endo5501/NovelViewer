## Why

ダウンロードの全 HTTP GET は唯一の choke point である `DownloadService._fetchPageResponse` を通るが、ここにはタイムアウトはあってもリトライが一切ない「一発勝負」になっている（F121）。そのため一時的な 503 やタイムアウトが即座に永続的な失敗として扱われ、文脈によって深刻度が異なる被害を生む:

- 1ページ目の目次取得失敗 → 例外がそのまま伝播し**ダウンロード全体が失敗**
- 2ページ目以降の目次取得失敗 → `indexTruncated=true` となり**一部エピソードが永久に欠落**
- 各エピソード本文の取得失敗 → `failedCount++`（次回更新で再取得されるが、その回は欠落）

サーバ側の瞬間的な不調でユーザのダウンロードが失敗・欠落するのは費用対効果の悪い体験であり、少数回のリトライで大きく改善できる。

## What Changes

- `_fetchPageResponse` に**一時的失敗限定の指数バックオフ・リトライ**を追加する。choke point 1か所に入れることで、目次1ページ目・目次後続ページ・エピソード本文の3文脈すべてが恩恵を受ける。
- リトライ対象は**HTTP 5xx と `TimeoutException` のみ**。
  - HTTP 4xx（404/403 等）は永続的失敗とみなし、**リトライせず即座に従来どおり失敗**させる。
  - `ClientException` / `SocketException` 等のネットワーク例外はリトライ対象に**含めない**（キャンセル起因の例外と混同するため。下記キャンセル整合を参照）。
- バックオフ待機は**キャンセルに協調**する: 各リトライ試行の前後と待機の前後で `CancellationToken.throwIfCancelled()` を確認し、キャンセルがリトライによって遅延・誤分類されないようにする。
- `maxRetries`（既定 2）と `retryBaseDelay`（指数バックオフの基準遅延）を `DownloadService` のコンストラクタ引数として**注入可能**にし、テストでは実時間を待たずに検証できるようにする（既存の `requestDelay` / `requestTimeout` と同じパターン）。
- 上記の挙動を `text-download` の「Episode download」要件に追記する。

## Capabilities

### New Capabilities
（なし）

### Modified Capabilities
- `text-download`: 「Episode download」要件に、一時的なフェッチ失敗（5xx / タイムアウト）に対する指数バックオフ・リトライと、4xx・キャンセルの非リトライ挙動を追記する。

## Impact

- コード: `lib/features/text_download/data/download_service.dart`（`_fetchPageResponse`、`DownloadService` コンストラクタ）。`fetchPage` 等の既存呼び出し経路は引数追加に追従。
- テスト: 逐次応答（例: 503→200）を返せるモックの追加が必要（既存 `routingClient` はステートレスで同一URLに毎回同じ応答を返すため）。`test/features/text_download/helpers/download_test_helpers.dart` にヘルパーを追加し、新規リトライテストを追加。
- 振る舞い: リトライ発生時はダウンロード総所要時間が最悪 `requestTimeout × (maxRetries+1) + バックオフ合計` まで延びる。成功時・4xx 時の所要時間は不変。
- 依存・API の追加なし。`DownloadService` のコンストラクタにオプション引数が増えるが既存呼び出しは後方互換。
