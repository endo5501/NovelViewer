## Context

`DownloadService` の全 HTTP GET は `_fetchPageResponse(Uri, {NovelSite?})` を経由する。現状の実装は:

1. `site.requestHeaders` と既定 User-Agent をマージしてヘッダを構築
2. `_client.get(...).timeout(requestTimeout)` を1回だけ実行
3. ステータスが 200 以外なら `HttpException` を throw

呼び出し元は3つ:

- `downloadNovel`（目次1ページ目）: 失敗は呼び出し側へ伝播 → ダウンロード全体失敗
- `_collectPagedIndex`（目次2ページ目以降）: 失敗は catch して `truncated=true`
- `_downloadEpisodes`（エピソード本文）: 失敗は catch して `failedCount++`

キャンセルは `cancelToken?.onCancel(_client.close)` により in-flight GET を `ClientException` として落とし、各 catch の先頭で `cancelToken?.throwIfCancelled()` を呼んでキャンセルを「失敗」や「truncation」と誤分類しないよう再分類している。

制約:
- 既存のキャンセル契約・truncation 契約・failedCount 契約を壊さないこと。
- テストは実時間を待たずに完結すること（CI 負荷・flaky 回避。F123 の教訓）。

## Goals / Non-Goals

**Goals:**
- 一時的な HTTP 5xx・タイムアウトを、少数回（既定2回）の指数バックオフでリトライし、瞬間的なサーバ不調による失敗・欠落を減らす。
- choke point（`_fetchPageResponse`）1か所への追加で、目次1ページ目・後続ページ・エピソード本文の3文脈すべてを一様にカバーする。
- リトライ回数・基準遅延を注入可能にし、テストを実時間ゼロで実行できるようにする。

**Non-Goals:**
- HTTP 429（レート制限）への対応。今回のスコープ外（必要なら別 change で `Retry-After` ヘッダ尊重とともに検討）。
- `ClientException` / `SocketException` 等ネットワーク例外のリトライ。キャンセル起因の例外と区別できないため対象外。
- 合成失敗や DB エラーなど HTTP 以外の経路のリトライ。
- リトライ可否・回数のユーザ向け設定 UI 化。

## Decisions

### 決定1: リトライは choke point（`_fetchPageResponse`）に集約する

`_fetchPageResponse` 内にリトライループを実装する。

- **理由**: GET は全てここを通る。1か所の変更で3文脈を均一にカバーでき、テストも一元化できる。エピソード本文（failedCount）だけでなく、より深刻な「目次1ページ目失敗＝全体失敗」「後続目次失敗＝欠落」も同時に緩和できる。
- **代替案**: `_downloadEpisodes` のエピソード取得 try のみにリトライを入れる（F121 の文言に忠実）。→ 目次取得の一時失敗を救えず、部分対応にとどまるため不採用。

### 決定2: リトライ対象は HTTP 5xx と `TimeoutException` のみ

```
isTransientStatus(code) := 500 <= code <= 599
```

- 200 → 即返す。
- 5xx かつ試行回数が残っている → バックオフして再試行。使い切ったら従来どおり `HttpException` を throw。
- 4xx（およびその他 200/5xx 以外） → **リトライせず**即 `HttpException`。404 は本当に存在しない・403 はブロックなので再試行は無駄かつ有害。
- `TimeoutException`（`.timeout()` 由来） → バックオフして再試行。使い切ったら rethrow。
- **理由**: 推奨「5xx/タイムアウトのみ」に忠実。永続的失敗を素早く失敗させ、無駄なリトライを避ける。

### 決定3: `ClientException` / ネットワーク例外はリトライしない

リトライループの `catch` は `TimeoutException` のみを捕捉し、それ以外の例外（`ClientException` 等）はそのまま外へ伝播させる。

- **理由**: キャンセルは `_client.close()` → `ClientException` として現れる。ネットワーク例外を一律リトライ対象にすると、キャンセルをリトライしてしまう（閉じたクライアントへの再試行で再び `ClientException`、かつバックオフ分だけキャンセル応答が遅延）。「5xx/timeout のみ」という狭いスコープがこの安全性を担保する。

### 決定4: バックオフはキャンセルに協調する

`_fetchPageResponse` に `CancellationToken? cancelToken` を引数追加し、3つの呼び出し元から現在の token を渡す（`fetchPage` 等 token を持たない経路は `null`）。リトライループでは:

- ループ先頭で `throwIfCancelled()`（閉じたクライアントへの再試行を防ぐ）
- バックオフ `Future.delayed` の前後で `throwIfCancelled()`

これによりキャンセルがリトライ・バックオフによって失敗/truncation に誤分類されたり、不要に遅延したりしない。`Future.delayed` 自体はキャンセルで中断されないが、待機後に必ず `throwIfCancelled()` するため、最大でも1回分のバックオフ待ちで確実にキャンセルが伝播する（既存の `requestDelay` 待機と同等の挙動）。

### 決定5: バックオフは指数、回数・基準遅延を注入可能にする

- `DownloadService` に `int maxRetries`（既定 `2`）と `Duration retryBaseDelay`（既定 `Duration(milliseconds: 500)`）を追加。
- n 回目（1始まり）の待機 = `retryBaseDelay * 2^(n-1)`（500ms → 1s）。
- **理由**: 既定2回・控えめなバックオフで体感悪化を抑える。テストは `retryBaseDelay: Duration.zero`（または極小）で実時間を待たずに検証（F123 の wall-clock flaky を踏襲しない）。

### 擬似コード

```dart
Future<http.Response> _fetchPageResponse(
  Uri url, {
  NovelSite? site,
  CancellationToken? cancelToken,
}) async {
  final headers = {'User-Agent': _userAgent, ...?site?.requestHeaders(url)};
  var attempt = 0;
  while (true) {
    cancelToken?.throwIfCancelled();
    try {
      final res = await _client.get(url, headers: headers).timeout(requestTimeout);
      if (res.statusCode == 200) return res;
      if (_isTransientStatus(res.statusCode) && attempt < maxRetries) {
        attempt++;
        await _backoff(attempt, cancelToken);
        continue;
      }
      throw HttpException('HTTP ${res.statusCode}', uri: url);
    } on TimeoutException {
      if (attempt < maxRetries) {
        cancelToken?.throwIfCancelled();
        attempt++;
        await _backoff(attempt, cancelToken);
        continue;
      }
      rethrow;
    }
  }
}

Future<void> _backoff(int attempt, CancellationToken? token) async {
  token?.throwIfCancelled();
  await Future.delayed(retryBaseDelay * (1 << (attempt - 1)));
  token?.throwIfCancelled();
}
```

## Risks / Trade-offs

- **[所要時間の増加]** 一時失敗が連発するとダウンロードが最悪 `requestTimeout × (maxRetries+1) + バックオフ合計` まで延びる。→ 既定2回・控えめなバックオフに抑え、4xx は即失敗で無駄打ちを排除。
- **[キャンセル遅延]** バックオフ `Future.delayed` 中のキャンセルは待機完了まで反映されない。→ 待機後に必ず `throwIfCancelled()`。既存の `requestDelay` と同等で、最大でも1バックオフ分。
- **[テストインフラ不足]** 既存 `routingClient` はステートレスで「503→200」を表現できない。→ 逐次応答モック（呼び出し回数で応答を切り替える）を `download_test_helpers.dart` に追加。
- **[二重リトライの懸念]** `_collectPagedIndex` / `_downloadEpisodes` は元々失敗を catch して truncated/failed にしているが、それは「リトライ使い切り後」に発生するため二重にはならない（リトライは `_fetchPageResponse` 内で完結し、使い切ってから例外が外へ出る）。
- **[429 非対応]** レート制限はリトライされず即失敗扱い。→ Non-Goal として明示。実際に問題化したら別 change で対応。
