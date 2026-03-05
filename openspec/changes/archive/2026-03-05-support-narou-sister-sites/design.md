## Context

NovelViewerのなろう対応（`NarouSite`クラス）は `url.host.contains('syosetu.com')` でサイト判定を行っており、`novel18.syosetu.com` のURLも受け付ける。HTMLフォーマットも同一のためパース処理は問題ない。

しかし、`novel18.syosetu.com` は年齢確認ゲートウェイがあり、`Cookie: over18=yes` を送信しないとHTTP 403エラーが返される。現在の `DownloadService._fetchPageResponse` は `User-Agent` のみをヘッダーに含めており、サイト固有のヘッダーを送信する仕組みがない。

## Goals / Non-Goals

**Goals:**
- `novel18.syosetu.com` からの小説ダウンロードを可能にする（年齢確認Cookie付与）
- サイトごとに追加HTTPヘッダーを定義できる拡張ポイントを設ける
- UIテキストで姉妹サイトのサポートを明示する
- テストカバレッジの追加

**Non-Goals:**
- ブラウザベースの年齢確認フローの実装（対話的なログイン・年齢確認は行わない）
- `novel18` を独立した `siteType` にすること（`narou` として統一）

## Decisions

### 1. NovelSiteに `requestHeaders` メソッドを追加

**決定**: `NovelSite` 抽象クラスに `Map<String, String> requestHeaders(Uri url)` メソッドを追加する。デフォルト実装は空のMapを返す。

**理由**: サイトごとに必要なヘッダー（Cookie等）を定義できる拡張ポイントを設けることで、`DownloadService` をサイト固有のロジックから分離できる。

**代替案**: `DownloadService` 内でURLホストを判定してCookieを追加する → サイト固有のロジックが `DownloadService` に漏れるため却下。

### 2. NarouSiteで novel18 URL判定時にCookieを付与

**決定**: `NarouSite.requestHeaders` で `url.host == 'novel18.syosetu.com'` の場合に `{'Cookie': 'over18=yes'}` を返す。

**理由**: `novel18.syosetu.com` の年齢確認ゲートウェイを通過するにはこのCookieが必要。固定値で十分。

### 3. DownloadServiceがサイトのrequestHeadersを使用

**決定**: `DownloadService` の `downloadNovel` メソッドに `NovelSite` を渡し、`_fetchPageResponse` でサイトの `requestHeaders` をマージする。

**実装方針**: `_fetchPageResponse` に `NovelSite?` パラメータを追加し、リクエスト時にサイトの `requestHeaders` と既存の `User-Agent` ヘッダーをマージする。

### 4. siteTypeは `narou` のまま統一

**決定**: `novel18.syosetu.com` のURLも `siteType: 'narou'` として扱う。フォルダ名も `narou_{novelId}` で統一。

## Risks / Trade-offs

- [年齢確認の変更] `novel18.syosetu.com` の年齢確認方式が将来変更された場合、Cookie値の更新が必要になる可能性がある → シンプルなCookie付与なので修正は容易。
- [Cookie固定値] `over18=yes` を固定値で送信する → 当該サイトの標準的な年齢確認方式であり、問題ない。
