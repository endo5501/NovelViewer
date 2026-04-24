## 1. 準備とフィクスチャ作成

- [x] 1.1 実ページ `https://kakuyomu.jp/works/16818093092974667738` の `__APOLLO_STATE__` を参考に、最小フィクスチャ用JSON（`Work` 1件 + `TableOfContentsChapter` 2〜3件 + `Episode` 5〜8件、章境界をまたぐ構造）を設計する
- [x] 1.2 ~~`test/features/text_download/fixtures/kakuyomu_index_apollo.html` として独立フィクスチャを作成~~ → 代わりに `kakuyomu_site_test.dart` 内に `_apolloState`／`_buildApolloHtml` ヘルパーを実装し、各シナリオで構成を変えやすくした（フィクスチャより柔軟）
- [x] 1.3 章境界フラット結合の検証用に、複数 `TableOfContentsChapter` をまたぐエピソードIDが連番化されることを確認できるフィクスチャ構造にする

## 2. テスト書き直し（TDD: 失敗確認まで）

- [x] 2.1 既存 `test/features/text_download/kakuyomu_site_test.dart` の `parseIndex` 関連テスト（`<a>` ベースの旧テスト群）を削除する
- [x] 2.2 `parseEpisode` 関連テストおよび `canHandle` / `normalizeUrl` / `siteType` / `extractNovelId` テストはそのまま残す
- [x] 2.3 新仕様 `parseIndex` のテストを追加する:
  - [x] 2.3.1 全エピソードが TOC 順で抽出される（章境界をまたぐ flat 結合）
  - [x] 2.3.2 `Episode.title` が Apollo `title` から取得される（"1話目から読む" のような DOM テキストに影響されない）
  - [x] 2.3.3 `Episode.url` が `https://<host>/works/<workId>/episodes/<episodeId>` 形式で組み立てられる
  - [x] 2.3.4 `Episode.index` が 1 から連番で章境界をまたいで連続する
  - [x] 2.3.5 `Episode.updatedAt` が Apollo `Episode.publishedAt` の値と一致する
  - [x] 2.3.6 `Episode.publishedAt` が欠落／null のとき `updatedAt` が null になる
  - [x] 2.3.7 `NovelIndex.title` が Apollo `Work.title` から取得される
  - [x] 2.3.8 `<script id="__NEXT_DATA__">` が無いHTMLでは `ArgumentError` が投げられる
  - [x] 2.3.9 不正なJSONを含む `<script id="__NEXT_DATA__">` で `ArgumentError` が投げられる
  - [x] 2.3.10 `__APOLLO_STATE__` が存在しないとき `ArgumentError` が投げられる
  - [x] 2.3.11 `ROOT_QUERY.work({"id":"<workId>"})` 参照が解決できないとき `ArgumentError` が投げられる
  - [x] 2.3.12 `Work.tableOfContentsV2` が空配列のとき `episodes: []` の `NovelIndex` を返し、`title` は `Work.title` を反映する
  - [x] 2.3.13 「1話目から読む」CTA が存在する DOM でも、Apollo state を参照することで第1話タイトルが Apollo の `Episode.title` になる（回帰防止テスト）
- [x] 2.4 `fvm flutter test test/features/text_download/kakuyomu_site_test.dart` を実行し、新規テストが期待どおり失敗することを確認する（13テスト失敗、既存16テスト通過）
- [x] 2.5 失敗状態でテスト変更分のみコミット（メッセージは英語、内容は "Add Kakuyomu Apollo state parsing tests" 程度）

## 3. 実装

- [x] 3.1 `lib/features/text_download/data/sites/kakuyomu_site.dart` の `parseIndex` を Apollo state ベースに書き換える
- [x] 3.2 `<script id="__NEXT_DATA__">` の中身を抽出し、`dart:convert` の `jsonDecode` でJSONパースする
- [x] 3.3 `props.pageProps.__APOLLO_STATE__` から `ROOT_QUERY.work({"id":"<workId>"})` 経由で `Work` エンティティを解決する
- [x] 3.4 `Work.tableOfContentsV2` の `__ref` を順に解決し、各 `TableOfContentsChapter.episodeUnions` の `__ref` を flatten して `Episode` 配列を構築する
- [x] 3.5 `Episode.url` を `Uri.parse('https://<host>/works/<workId>/episodes/<id>')` で組み立てる（host は `baseUrl.host` を使用）
- [x] 3.6 `Episode.title` / `Episode.publishedAt` をマップして `Episode(index, title, url, updatedAt)` を生成する（index は 1 から連番）
- [x] 3.7 `NovelIndex.title` を `Work.title` から設定する
- [x] 3.8 D6 のエラー処理（`<script id="__NEXT_DATA__">` 不存在、JSON parse 失敗、`__APOLLO_STATE__` 欠落、`Work` 参照不解決）に対し、原因が分かるメッセージで `ArgumentError` を投げる
- [x] 3.9 旧実装の `_titleSelectors` 定数および DOM ベースの `<a>` 走査コードを削除する
- [x] 3.10 `_bodySelectors` および `parseEpisode` には変更を加えないことを確認する

## 4. 検証

- [x] 4.1 `fvm flutter test test/features/text_download/kakuyomu_site_test.dart` を実行し、新テストがすべて通過することを確認する（29/29）
- [x] 4.2 `fvm flutter test` を実行し、他のテスト（特に `download_service_test.dart`、`incremental_download_test.dart`）にリグレッションがないことを確認する（1212/1212 pass）
- [x] 4.3 `fvm flutter analyze` を実行し、警告／エラーがないことを確認する（No issues found）
- [ ] 4.4 アプリを起動し、`https://kakuyomu.jp/works/16818093092974667738` を実際にダウンロードして、78話すべてが取得され、第1話のタイトルが「第1話 「お願いだ……〈レイダス〉、動いてくれよ！」」になることを確認する（**ユーザによる手動検証が必要**）
- [ ] 4.5 既存の他カクヨム作品（短編／中編）でも目次取得が正常動作することを抜き取りで確認する（**ユーザによる手動検証が必要**）

## 5. 最終確認

- [x] 5.1 simplifyスキルを使用してコードレビューを実施（`Uri.https`→`Uri.https`修正、`_readPath`インライン化、エラーメッセージに`baseUrl`追加、未使用引数削除）
- [x] 5.2 codexスキルを使用して現在開発中のコードレビューを実施（ROOT_QUERY経由でWork解決、内部ノードの型違反/欠落を厳格にArgumentError化、`baseUrl.replace`で URL再構築、schema drift テスト追加）
- [x] 5.3 `fvm flutter analyze`でリントを実行（No issues found）
- [x] 5.4 `fvm flutter test`でテストを実行（1217/1217 pass）
