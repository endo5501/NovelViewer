## Context

NovelViewer のダウンロード機構は、サイトごとの差異を `NovelSite` 抽象クラス（`lib/features/text_download/data/sites/novel_site.dart`）に閉じ込めるプラグイン構造になっている。URLは `NovelSiteRegistry.findSite(url)` が登録済みアダプタを順に `canHandle` で照合してルーティングする。各アダプタは `siteType` / `canHandle` / `extractNovelId` / `normalizeUrl` / `requestHeaders` / `decodeBody` / `parseIndex` / `parseEpisode` を実装する。`DownloadService` は `parseIndex` が返す `NovelIndex`（`title` / `episodes[]` / `bodyContent?` / `nextPageUrl?`）を使ってエピソードを順に取得・保存し、差分更新は各エピソードの `updatedAt` 文字列の完全一致比較（`_shouldDownload`）で判定する。

本変更はこの構造に4つ目のサイト「ハーメルン」(syosetu.org) を追加する。実HTMLを調査した結果、構造は「なろう」(`NarouSite`) に最も近く、`#honbun` 内の `<p>` 段落・目次の更新日付き一覧という共通点がある。

## Goals / Non-Goals

**Goals:**

- `https://syosetu.org/novel/<id>/`（およびエピソードURL）を対応サイトとして認識し、目次・本文を取得できる。
- 章見出しをまたいで全話をフラットなエピソード一覧として取得する。
- エピソードURLをリンクの `href`（ファイル番号）から構成し、表示話数とファイル番号のズレに耐える。
- R-18 作品を特別な処理なしで取得できる。
- 一話完結（短編）作品を `bodyContent` として扱う。
- 既存サイト（なろう・カクヨム・青空）の挙動・データに一切影響を与えない。
- TDD（テストファースト）で実装する。

**Non-Goals:**

- ハーメルンのログイン認証や、作者が個別に閲覧制限した会員限定作品の取得（本変更では非対応。検知してエラー表示に留める余地はあるが必須としない）。
- 章（章見出し）情報をデータモデルに保持すること（既存 `Episode` モデルに章フィールドは無く、カクヨム同様フラット化する）。
- 既存 `Episode` / `NovelIndex` / `NovelMetadata` データモデルの変更。
- ハーメルン専用のUI追加（対応サイト判定に1件増えるのみ）。

## Decisions

### 決定1: `NarouSite` をテンプレートに `HamelnSite` を新規実装する

`NovelSite` を実装する単一クラス `HamelnSite` を `sites/hameln_site.dart` に新規作成し、`NovelSiteRegistry._sites` に1行追加する。本文の `<p>` 連結ロジック（`blockToText` で `\n` 連結）は `NarouSite.parseEpisode` と同型のため、その方式を踏襲する。

- **代替案**: 既存サイトクラスを汎用化して共通基底に切り出す → 現時点では重複が小さく、過度な抽象化はリスク。各サイトが独立クラスである既存方針を維持する。

### 決定2: `canHandle` はホスト `syosetu.org` かつ `/novel/<数字>/` パスで判定

なろうの `syosetu.com` とは TLD が異なる（`.org` vs `.com`）ため誤判定の心配は小さいが、`syosetu.org` の非小説ページ（ランキング `?mode=rank` 等）を除外するため、ホスト一致に加えてパスが `/novel/<数字>` で始まることを条件にする。

- **代替案**: ホスト一致のみ → トップページ等も対応扱いになり `unsupportedSiteError` の意図と外れるため不採用。

### 決定3: エピソードURLは表示番号ではなく `href` のファイル番号から構成する

実調査で、リンク表示テキストの先頭番号（例「3」）と実体ファイル（例 `./4.html`）がズレるケースを確認した（削除・並べ替えによる）。`index` は出現順の1始まり連番、`url` は `baseUrl.resolve(href)` で構成する。これにより表示番号に依存せず正しいページを取得できる。

- **代替案**: 表示番号を `index`/URLに使う → ファイル欠番でダウンロード対象を誤るため不採用。

### 決定4: `updatedAt` はサイト生フォーマットのまま格納する（整形しない）

`updatedAt` は `DownloadService._shouldDownload` が「前回保存文字列との完全一致比較」にのみ使用し、日付として解釈・大小比較はしない。したがって各サイト独自フォーマットで良い。ハーメルンの `<NOBR>2026年02月25日(水) 22:58</NOBR>` の生テキスト（`(改)` 改稿マーカーがあれば含む）をそのまま格納する。整形・なろう形式への変換はしない（変換すると改稿マーカーを落とし差分検知が壊れるリスクがある）。取得失敗で `null` でも `_shouldDownload` は `true`（毎回再DL）にフォールバックするため安全。

### 決定5: 短編判定は「目次行が無く `#honbun` がある」で行う

複数話の目次ページには `#honbun` が無く、エピソード行（`class="bgcolor2/3"` のテーブル行）が存在する。一話完結作品はその逆になる。`parseIndex` でエピソードを収集した結果が空であれば `parseEpisode(html)` で本文を取り出し `bodyContent` に入れる（`NarouSite` の短編フォールバックと同型）。

### 決定6: 文字コードはUTF-8デフォルト。ただしCloudflare対策で正直なUser-Agentに上書き

実調査でハーメルンは UTF-8 配信（Content-Typeヘッダに`charset=UTF-8`明示）であり、R-18 作品も年齢Cookie無しで取得できる。よって `decodeBody` は基底のデフォルト（`response.body`）でよく、青空の Shift-JIS のようなオーバーライドや novel18 の `over18=yes` Cookie は不要。

一方、`syosetu.org` は Cloudflare 配下にあり、アプリ既定の**Chrome偽装 User-Agent では HTTP 403**（bot検知）になることが判明した。検証の結果:

- Chrome偽装UA（既定）→ 403。`Accept`/`Accept-Language` を足しても 403。
- `Accept-Encoding: gzip, deflate, br`（brotli対応＝本物Chromeの特徴）を足すと通過するが、CFがbrotliで返し dart:io が自動解凍できず別問題が発生。
- **正直な非ブラウザUA（`Dart/x` や `NovelViewer ...`）→ 200**（gzipで返り自動解凍、日本語正常）。

根本原因は「Chromeを名乗るのに本物Chromeの特徴を欠く不整合」をCFが弾くこと。したがって `requestHeaders` で **`User-Agent` を正直なアプリ識別子（`NovelViewer (Flutter desktop app)`）に上書き**する。`_fetchPageResponse` は `{'User-Agent': 既定, ...siteHeaders}` の順でマージするため、サイト側の指定が既定のChrome偽装を上書きする。グローバル既定（Chrome偽装）は他サイト（なろう等、ブラウザUAを要する可能性）のため維持し、上書きはHamelnSiteに限定する。

- **代替案**: ブラウザ一式ヘッダ＋brotli解凍を実装してChrome偽装を貫く → brotli解凍の追加依存と複雑性。正直UAの方が単純・堅牢で、スクレイピング作法としても適切。

### 決定7: R-18の年齢確認Cookie（over18）を常時送信

一部のR-18作品（特に単話）は、本文の代わりに「あなたは18歳以上ですか？」の中間ページを返す。サイトの「はい」フロー（`?mode=r18_cs_end&nid=...&volume=1`）が `Set-Cookie: over18=off`（ドメイン全体）を設定し、以後本文が返ることを実機確認した。よって `requestHeaders` で **`Cookie: over18=off` を常時送信**する。検証:

- R-18短編(415332): Cookie無し→中間ページ（`#honbun`無し→bodyContent=null→0話でフォルダのみ生成、本文DL失敗）。Cookieあり→`#honbun`取得、bodyContent生成、DL成功。
- 非R-18作品(402955): Cookieありでも正常（ToC 25話、ゲート無し）＝無害。
- Cookieは作品横断（domain=.syosetu.org）で1つ効くため、ホストで区別できないHamelnでは全リクエストに無条件付与が最善。

注: 一部のR-18作品(238682)はCookie無しでも本文が返る（作品ごとに中間ページの有無が異なる）。無条件付与は両者を吸収する。

## Risks / Trade-offs

- **[表示番号とファイル番号のズレ]** → `href` のファイル番号を正としてURLを構成し、`index` は出現順連番にする。フィクスチャに番号がズレた行を含めてテストで担保する。
- **[会員限定／要ログイン作品]** → 一般的なR-18は素通りするが、作者が個別制限した作品は本文取得時に `mode=login` への誘導ページが返る可能性がある。本変更では対象外。必要なら将来、誘導検知時に明示エラーを出す拡張余地を残す。
- **[超長編の目次ページング]** → 調査範囲では目次は単一ページだったが、極端な長編でページ分割される可能性は未確認。実装時に1件確認し、必要なら `nextPageUrl`（なろう同様の「次へ」検出）で対応する。当面は単一ページ前提（`nextPageUrl` は null）。
- **[HTMLマークアップの将来変更]** → スクレイピング全般のリスク。`#honbun` 等のセレクタが変われば破綻する。既存サイト同様、フィクスチャベースのテストで早期検知する。
- **[`href` が無引用符 (`href=./4.html`)]** → `html` パッケージは正常にパース可能と確認済み。リスク低。

## Migration Plan

新規追加のみで破壊的変更はない。`NovelSiteRegistry` への1行追加が有効化トリガーで、ロールバックは当該追加とファイルの取り消しで完結する。データ移行・スキーマ変更は不要。

## Open Questions

- 短編（一話完結）作品の実フィクスチャは実装時のTDDで1件採取する（調査時点では複数話作品のみ採取済み）。
- 超長編での目次ページング有無を実装時に1件確認する。
