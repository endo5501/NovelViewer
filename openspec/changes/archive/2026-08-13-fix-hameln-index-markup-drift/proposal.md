## Why

ハーメルン (syosetu.org) が目次ページのマークアップを刷新し、`HamelnSite.parseIndex` が全話を取りこぼすようになった。目次は「`class="bgcolor2"/"bgcolor3"` を持つ `<table>` 行」から「`<section class="episode-list">` 内の `<ul>/<li>` リスト」へ置き換わっており、現行セレクタは1件もヒットしない。

結果として `parseIndex` は `episodes: []` を返し、連載作品の目次には `#honbun` が無いため短編フォールバックも空になる。`NovelIndex(episodes: [], bodyContent: null)` は `DownloadService` の空目次ガード (F118) に捕まり、新規ダウンロード・既存作品の更新のいずれも次のエラーで失敗する。

> エラー: 目次を取得できませんでした。サイトの仕様変更か、URLが正しくない可能性があります

2026-08-13 に実サイトを取得して確認した事実:

- **壊れているのは目次パースのみ。** Cloudflare 回避用の正直な User-Agent は今も有効（アプリのUAで HTTP 200、ブラウザ偽装UAは今も 403）。`over18` Cookie、各話ページの `#honbun` + `<p>` 構造、URL判定・ID抽出・正規化、連載の `span[itemprop="name"]` タイトルはいずれも無変更。
- **短編のインライン本文経路は健在。** 短編作品の目次ページには `episode-list` セクション自体が存在せず `#honbun` が直接ある（例: `/novel/123475/`）。見出しの自己リンク `<a href=./>` も健在で、タイトル抽出は連載・短編とも現行のまま動作する。
- **テストは緑のまま本番が壊れていた。** `test/fixtures/text_download/hameln_index_valid.html` は旧マークアップを模した手書き620バイトのフィクスチャで、ドリフト検知 (F118) は実行時にしか働かないため、テストは旧構造を検証し続けていた。

## What Changes

- **目次パースの新マークアップ対応**: `HamelnSite.parseIndex` の走査対象を `tr.bgcolor2 / tr.bgcolor3` から `li.episode-list__item` 内の `a.episode-list__link` へ変更する。章見出し (`li.episode-list__chapter`) は従来どおりフラット化して無視する。エピソードURLは引き続きリンクの `href`（`./N.html` のファイル番号）を真とし、`index` は出現順の1始まり連番とする。
- **エピソードタイトルの取得元変更と、話数カウンタ除去の撤廃 (BREAKING)**: タイトルは `span.episode-list__title` から取得する。加えて、先頭の `^\d+　` を「ハーメルンの自動表示カウンタ」とみなして削っていた処理を**撤廃**する。実サイトを確認した結果、自動カウンタは存在せず（`./1.html` は「プロローグ」で数字なし）、先頭の数字は**作者が書いたタイトルの一部**だった。現行処理は作者のタイトルを一貫性なく削っている（「10 　京都参戦」は半角スペース混じりで正規表現に当たらず削られない）。
- **更新日時抽出の作り直し (BREAKING)**: `<NOBR>` の日付セルは消滅し、`<time class="episode-list__date">2026/02/25 22:58</time>` になった。さらに `<time>` のテキストは**投稿日時で改稿しても変化せず**、改稿マーカーも `(改)` の固定文字列なので、両者だけでは2回目以降の改稿を検知できない。改稿ごとに変化する唯一の値は `<span class="episode-list__revision" title="2026/03/01 06:05改稿">` の `title` 属性なので、これを `updatedAt` に取り込み、既存要件「改稿すると `updatedAt` が変わる」を維持する。
- **エピソードファイル名移行の一般化 (`text-download`)**: 上記タイトル変更により、既存のダウンロード済みファイル名が変わる（`0004_運ぶための力.txt` → `0004_3　運ぶための力.txt`）。現行の `migrateEpisodeFileNamePadding` (F104) は `(index, safeName(title))` をキーにするためタイトル変更を対象外としており、`saveEpisode` も旧名ファイルを削除しないので、放置すると旧ファイルが残って同じ話が2件に見える。移行処理の同一エピソード判定を「現在のタイトル」だけでなく「エピソードキャッシュに記録された前回のタイトル」にも一致させるよう一般化し、タイトル変更でも正しくリネーム／削除されるようにする。あわせて、キャッシュが別のindexを記録しているエピソード（話の挿入・削除でindexがずれたもの）は移行対象から外し、重複タイトル作品で別エピソードのファイルを掴む既存の穴も塞ぐ。
- **フィクスチャの実HTML化**: 手書きの旧マークアップフィクスチャを、実サイトから取得したHTMLをサニタイズしたものに差し替える。これにより「テストは緑・本番は壊れている」状態を再発しにくくする。

**受容する影響**: `updatedAt` の形式が旧形式 (`2026年02月25日(水) 22:58`) と一致しなくなるため、ダウンロード済みのハーメルン作品は初回更新時に**全話が再取得**される。これはユーザ判断で許容済み。

## Capabilities

### New Capabilities

<!-- なし -->

### Modified Capabilities

- `hameln-download`: `Hameln table of contents parsing` を REMOVED とし、新マークアップに対応した `Hameln episode list parsing` を ADDED で置き換える（要件名の「table of contents」がサイト側の実態と合わなくなったこと、および「カウンタを除去する」シナリオが retired behaviour になり MODIFIED では表現できないため）。`Hameln episode update date extraction` は MODIFIED で `<time>` + 改稿 `title` 属性に対応する。作品タイトル抽出（`Hameln title extraction`）は連載・短編とも現行経路が有効なため変更しない。
- `text-download`: `Episode filename zero-pad width migration` の同一エピソード判定を、エピソードキャッシュに記録された前回タイトルも許容するよう一般化し、「タイトル変更ファイルは移行対象外」というシナリオを差し替える。

## Impact

- コード:
  - `lib/features/text_download/data/sites/hameln_site.dart`（`parseIndex` の走査ロジック、`_extractUpdateDate`、`_displayCounterPattern` 撤廃、`_extractTitle` の短編経路）
  - `lib/features/text_download/data/download_service.dart`（`migrateEpisodeFileNamePadding` の同一エピソード判定一般化と、呼び出し側からのURL／キャッシュ受け渡し）
- テスト: `test/features/text_download/hameln_site_test.dart`、`test/features/text_download/index_fixture_parsing_test.dart`、ファイル名移行のテスト
- フィクスチャ: `test/fixtures/text_download/hameln_index_valid.html`（連載・実HTML）、`hameln_index_drifted.html`（旧マークアップをドリフト検体として再利用）、短編用フィクスチャの追加
- データ: ダウンロード済みハーメルン作品の全話再取得が一度だけ発生する（受容済み）。エピソードキャッシュDBのスキーマ変更は無い。
- i18n: 新規のユーザ向け文言は無し（既存のエラー文言のまま）。
- ドキュメント: `docs/specs/maintenance/07-external-integrations.md` の INV-0116 行参照の更新。

## Non-Goals

- ハーメルン以外のサイトアダプタの挙動変更（`migrateEpisodeFileNamePadding` の一般化は全サイト共通コードだが、既存の同一タイトル経路の挙動は変えない）。
- 章（章見出し）情報のデータモデル保持。従来どおりフラット化する。
- 読める話が0件の作品（目次リストが空で本文も無く、各話URLが「存在しない話数が指定されています」を返すもの。例: `/novel/402501/`）への特別対応。既存の空目次ガードでエラーになるのが妥当な挙動であり、本変更の対象外とする。
- `saveEpisode` 側での旧ファイル削除（移行処理側で解決するため不要）。
