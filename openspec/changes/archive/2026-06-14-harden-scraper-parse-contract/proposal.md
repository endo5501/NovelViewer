## Why

スクレイパーのパース契約と入力検証に「静かな失敗」と防御の非対称が残っている（Tech Debt Audit F118 / F119 / F120）。とくに目次のセレクタがサイト改修で総外しになると、`DownloadService` は空フォルダを作って `episodeCount=0` の「完了」として報告し、ユーザにもログにも異常が伝わらない。この挙動は現行の `text-download` spec にも「episodes空かつ body 無し → episodeCount=0 で完了」とそのまま明文化されてしまっている。ダウンロードの「静かな失敗」三点セット（F102/F103/F105）はエピソード単位までは塞いだが、**目次単位の全滅**は素通りのままなので、ここを契約レベルで閉じる。

## What Changes

- **F118 目次全滅ガード**: `DownloadService.downloadNovel` の `parseIndex` 直後（目次1ページ目）に下流ガードを追加する。`episodes` が空 **かつ** `bodyContent == null` のとき、空フォルダ作成や「完了」報告を行わず、新設の `EmptyIndexException` を呼び出し側へ伝播する（目次1ページ目の取得失敗と同じ扱い＝UI は error 表示）。Aozora と短編は `bodyContent` を立てるため、この条件には該当せず従来どおり成功する。**BREAKING**（spec 上の挙動変更）: 既存シナリオ「Index page has no episodes and no body text → episodeCount=0 で完了」を、`EmptyIndexException` を投げて呼び出し側へ伝播する挙動へ差し替える。
- **F119 ホスト/スキーム検証の一本化**: `KakuyomuSite.canHandle` の緩い `url.host.contains('kakuyomu.jp')`（`kakuyomu.jp.evil.com` にもマッチ）を、他3アダプタと同じ厳密ホスト集合 `{'kakuyomu.jp', 'www.kakuyomu.jp'}` ＋ `/works/<id>` パスチェックに変更する。加えて `NovelSiteRegistry.findSite` に `url.scheme == 'https'` 限定を集約し、全アダプタ一括で `http` などの非HTTPS URL を拒否する。
- **F120 User-Agent 決定の一本化**: 既定の Chrome 偽装 UA と Hameln の正直 UA が「ヘッダ spread 順（`siteHeaders` が後勝ち）」という暗黙契約で分岐している状態を、`NovelSite.requestHeaders` を UA 決定の唯一の場所として明文化し、`siteHeaders` が既定 UA を上書きする優先順位をテストで固定する。
- **F122（一部）テスト基盤**: 各アダプタ（narou / kakuyomu / hameln / aozora）の **目次ページ**のサニタイズ済み実HTMLフィクスチャと、失敗系テスト（空目次→`EmptyIndexException`、ホスト偽装→`findSite==null`、`http` スキーム→`findSite==null`、UA 上書きの優先順位）を追加する。TDD 厳守で、まず現挙動を固定するテストから着手する。

## Capabilities

### New Capabilities
<!-- なし。既存 text-download capability の要件変更として扱う。 -->

### Modified Capabilities
- `text-download`: 目次が全滅したときの挙動を「episodeCount=0 で完了」から「`EmptyIndexException` を伝播」へ変更（F118）。サイトルーティングの入力検証として、厳密ホスト一致と HTTPS スキーム限定の要件を追加（F119）。サイト固有ヘッダ（とくに User-Agent）が既定ヘッダを上書きするという優先順位を要件として明文化（F120）。

## Impact

- コード:
  - `lib/features/text_download/data/download_service.dart`（`downloadNovel` に目次全滅ガード／新例外 `EmptyIndexException` の定義・送出）
  - `lib/features/text_download/data/sites/novel_site.dart`（`NovelSiteRegistry.findSite` に HTTPS スキーム限定を集約。UA 決定経路の明文化）
  - `lib/features/text_download/data/sites/kakuyomu_site.dart`（`canHandle` を厳密ホスト集合＋パスチェックへ）
- 呼び出し側: `EmptyIndexException` を受ける provider 層（`text_download_providers.dart`）で、目次全滅をローカライズ済みエラーとして表示する経路（既存の目次1ページ目失敗と同じ扱い）。
- テスト: `test/features/text_download/`（新規失敗系テスト）、`test/fixtures/text_download/`（各アダプタの目次HTMLフィクスチャ追加）。
- i18n: 目次全滅をユーザに示す文字列を追加する場合は `.arb`（en/ja/zh）にフルパリティで追加。
- Non-Goal（本change対象外）:
  - Narou / Hameln のアダプタ内 throw 化（下流ガードが結果を保証するため任意のポリッシュ。やるなら別change）。
  - F121 取得リトライ（指数バックオフ）。直交するネットワーク回復性のため後続change `add-scraper-fetch-retry` で対応。
