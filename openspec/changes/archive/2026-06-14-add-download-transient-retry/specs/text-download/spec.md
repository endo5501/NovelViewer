## ADDED Requirements

### Requirement: Transient fetch retry with exponential backoff

ダウンロードの全 HTTP GET（目次1ページ目・後続の目次ページ・各エピソード本文）を行う共通フェッチ経路は、一時的なフェッチ失敗に対して指数バックオフでリトライを行う SHALL。リトライ対象は **HTTP 5xx ステータス**（500–599）と、リクエストタイムアウトによる `TimeoutException` の**2種のみ**とする。

- リトライ回数の上限（`maxRetries`、既定 2）と、指数バックオフの基準遅延（`retryBaseDelay`）は `DownloadService` のコンストラクタ引数として注入可能でなければならない MUST。n 回目（1始まり）の待機は `retryBaseDelay * 2^(n-1)` とする。
- HTTP 200 はそのまま成功として返す SHALL。
- HTTP 4xx およびその他 200/5xx 以外のステータスは永続的失敗とみなし、**リトライせず**直ちに従来どおりの `HttpException` を送出する SHALL。
- `ClientException` / `SocketException` 等のネットワーク例外はリトライ対象に**含めない** SHALL（呼び出し側へそのまま伝播させる）。これはキャンセル起因の例外（クライアントの `close()` による中断）をリトライ・誤分類しないためである。
- リトライ上限を使い切った後の最終的な失敗の扱いは、文脈ごとの既存契約を維持する SHALL: 目次1ページ目はキャンセル以外の例外を呼び出し側へ伝播、後続の目次ページは `indexTruncated=true`、エピソード本文は `failedCount` の加算。
- バックオフはキャンセルに協調する SHALL: 各リトライ試行の前、およびバックオフ待機の前後で `CancellationToken.throwIfCancelled()` を確認し、キャンセルがリトライ・バックオフによって失敗や truncation に誤分類されたり過度に遅延したりしないようにする。

#### Scenario: 一時的な 5xx の後に成功する（エピソード本文）
- **WHEN** あるエピソード本文の取得が初回 HTTP 503 を返し、再試行で HTTP 200 を返す
- **THEN** システムはバックオフ後に再試行して本文を取得・保存・キャッシュ登録し、`failedCount` を加算しない

#### Scenario: 一時的な 5xx の後に成功する（後続の目次ページ）
- **WHEN** 2ページ目以降の目次取得が初回 HTTP 503 を返し、再試行で HTTP 200 を返す
- **THEN** システムは再試行して当該目次ページを取得・マージし、`indexTruncated` を `true` にしない

#### Scenario: 5xx がリトライ上限まで続いたエピソードは失敗扱い
- **WHEN** あるエピソード本文の取得が `maxRetries + 1` 回連続で HTTP 5xx を返す
- **THEN** システムは `failedCount` を加算し WARNING をログ出力して次のエピソードへ進む（既存の失敗契約を維持）

#### Scenario: 5xx がリトライ上限まで続いた後続目次は truncation 扱い
- **WHEN** 2ページ目以降の目次取得が `maxRetries + 1` 回連続で HTTP 5xx を返す
- **THEN** システムはそこまでに収集したエピソードを保持したまま `indexTruncated` を `true` とし、目次取得を打ち切る

#### Scenario: 5xx がリトライ上限まで続いた1ページ目目次は全体失敗
- **WHEN** 目次1ページ目の取得が `maxRetries + 1` 回連続で HTTP 5xx を返す
- **THEN** システムは最終的な `HttpException` を呼び出し側へ伝播させ、空の小説フォルダを残さない（既存の最初の目次失敗と同じ扱い）

#### Scenario: 4xx はリトライされない
- **WHEN** あるフェッチが HTTP 404（または 403 等の 4xx）を返す
- **THEN** システムは再試行せず、ちょうど1回のリクエストで従来どおり失敗として扱う

#### Scenario: タイムアウトの後に成功する
- **WHEN** あるフェッチが初回はリクエストタイムアウト（`TimeoutException`）となり、再試行で HTTP 200 を返す
- **THEN** システムはバックオフ後に再試行して成功する

#### Scenario: バックオフ待機中のキャンセルはキャンセルとして扱う
- **WHEN** リトライのバックオフ待機中、または再試行の直前にダウンロードがキャンセルされる
- **THEN** システムはキャンセルを送出し、その回の失敗を `failedCount` の加算や `indexTruncated` として誤分類しない

#### Scenario: リトライ回数とバックオフ基準遅延は注入可能
- **WHEN** `DownloadService` が `maxRetries` と `retryBaseDelay` を指定して生成される
- **THEN** リトライ挙動はその値に従い、テストは実時間の待機なしに（`retryBaseDelay` を極小値にして）検証できる
