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

### 決定6: 文字コードと追加ヘッダは不要（UTF-8 / ヘッダなし）

実調査でハーメルンは UTF-8 配信であり、R-18 作品も素の User-Agent のみで目次・本文がフル取得できることを確認した。`decodeBody` は基底のデフォルト（`response.body`）、`requestHeaders` は空マップとし、青空の Shift-JIS のようなオーバーライドや、なろう novel18 の `over18=yes` Cookie は実装しない。

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
