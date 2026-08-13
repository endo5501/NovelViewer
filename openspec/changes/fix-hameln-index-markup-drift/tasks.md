## 1. フィクスチャ整備と先行失敗テスト（TDD: Red）

- [ ] 1.1 現状の関連テストが緑であることを確認してから着手する（`fvm flutter test test/features/text_download/`）
- [ ] 1.2 実サイトから検体HTMLを取得する（UA: `NovelViewer (Flutter desktop app)`、Cookie: `over18=off`）。調査時に取得済みの検体がスクラッチパッドに残っていれば流用可（`idx.html` = 連載目次 / `ep1.html` = 各話 / `q_123475.html` = 短編。ただしスクラッチパッドはセッション限りなので、下記URLが正となる）
  - 連載目次: `https://syosetu.org/novel/402955/`（章見出しあり・改稿マーカーあり／なし混在）
  - 短編: `https://syosetu.org/novel/123475/`（`episode-list` 無し・`#honbun` あり）
  - 各話本文: `https://syosetu.org/novel/402955/1.html`（`#maegaki` / `#honbun` / `#atogaki`）
- [ ] 1.3 取得HTMLをサニタイズ（広告・トラッキングスクリプト・不要なヘッダフッタ除去、本文短縮）して `test/fixtures/text_download/` に配置する: `hameln_index_valid.html`（新マークアップで差し替え）/ `hameln_index_short_story.html`（新規）/ `hameln_episode_valid.html`（新規、既存があれば差し替え）
- [ ] 1.4 既存の旧マークアップ検体（現行 `hameln_index_valid.html` の内容）を、新実装で0件になることを確認する回帰検体として保持する（`hameln_index_legacy_table.html` として残すか `hameln_index_drifted.html` に統合するかは実装時に判断）
- [ ] 1.5 `hameln_site_test.dart` に新マークアップ用の失敗テストを追加する: 章見出しをまたいだフラット化、`index` の1始まり連番、URLが `href` のファイル番号由来、`span.episode-list__title` からのタイトル取得。Red を確認
- [ ] 1.6 タイトルのカウンタ非除去テストを追加する: `3　運ぶための力` はそのまま、`プロローグ` もそのまま、`10 　京都参戦` もそのまま。Red を確認
- [ ] 1.7 `updatedAt` の失敗テストを追加する: 改稿マーカー無し → `<time>` テキストのみ / 改稿マーカーあり → `2026/02/21 16:20 (2026/03/01 06:05改稿)` / `title` 属性の変化で値が変わる / `<time>` 無し → null。Red を確認
- [ ] 1.8 短編の回帰テストを追加する: `episodes` が空・`bodyContent` が非null・タイトルが `<title>` フォールバック由来で正しいこと。Red/Green を確認
- [ ] 1.9 `index_fixture_parsing_test.dart` のハーメルン節を新フィクスチャに合わせて更新する（valid → エピソードあり、drifted / legacy-table → `episodes` 空かつ `bodyContent` null）
- [ ] 1.10 `hameln_site_test.dart` の**旧マークアップ前提の既存テストを新マークアップへ書き換える**。インラインHTML（`tr class="bgcolor2/3"` + `<NOBR>`）を使っているテスト群が対象: `flattens episodes across chapters` / `assigns sequential 1-based index` / `URL uses href file number` / `first episode URL resolves from href` / `stores updatedAt verbatim …`（2件）/ `does not populate bodyContent for multi-part work` / `picks the episode anchor even when a non-episode anchor precedes it` / `excludes phantom rows linking to other novels`
- [ ] 1.11 `episode title strips Hameln's leading display counter` テストを**削除し**、1.6 のカウンタ非除去テストで置き換える（撤廃する挙動を検証しているため残せない）
- [ ] 1.12 ファイル名移行の失敗テストを追加する: 同indexでタイトルが変わりキャッシュが前回タイトルを保持している場合にリネームされること、`newName` が既存なら旧ファイルが削除されること、キャッシュに該当が無ければ触らないこと。Red を確認

## 2. HamelnSite の目次パース対応（実装: Green）

- [ ] 2.1 `parseIndex` の走査対象を `tr.bgcolor2 / tr.bgcolor3` から `li.episode-list__item` 内の `a.episode-list__link` へ変更する（章見出し `li.episode-list__chapter` はエピソードリンクを持たないため自然に除外される）
- [ ] 2.2 `href` が `^(?:\./)?\d+\.html$` にマッチすることの確認は防御として維持する
- [ ] 2.3 タイトル取得を `span.episode-list__title` のテキスト `trim()` に変更する
- [ ] 2.4 `_displayCounterPattern` とその適用を削除する
- [ ] 2.5 1.5 / 1.6 のテストが緑になることを確認する

## 3. 更新日時抽出の作り直し（実装: Green）

- [ ] 3.1 `_extractUpdateDate` を新マークアップ用に書き換える: `time.episode-list__date` のテキストを基準値とし、`datetime` 属性は使わない（多くのエントリに存在しないため）
- [ ] 3.2 `span.episode-list__revision` の `title` 属性が存在する場合、`"{timeテキスト} ({title属性})"` の形式で連結する
- [ ] 3.3 `<time>` が無い場合は null を返す
- [ ] 3.4 1.7 のテストが緑になることを確認する

## 4. ファイル名移行の一般化（実装: Green）

- [ ] 4.1 `migrateEpisodeFileNamePadding` の引数にエピソードのURLと `Map<String, EpisodeCache>` を渡せるようにする（既存呼び出し側の受け渡しを含む）
- [ ] 4.2 同一エピソード判定を `restName == safeName(現在のタイトル)` **または** `restName == safeName(cache[url].title)` の OR 条件に拡張する。キャッシュに該当が無い／一致しない場合はファイルに触らない
- [ ] 4.3 リネーム／削除の分岐、冪等性、no-abort 契約（個別失敗は WARNING ログのみ）を既存のまま維持する
- [ ] 4.4 1.12 のテストが緑になることを確認する
- [ ] 4.5 既存のパッド幅移行テスト（99→100 / 100→99 / 冪等 / 空タイトル / キャッシュ非変更）が回帰していないことを確認する

## 5. 実サイトでの動作確認

- [ ] 5.1 連載作品を新規ダウンロードし、章をまたいで全話取得できること・タイトルが作者表記どおりであることを確認する
- [ ] 5.2 既存のダウンロード済みハーメルン作品を更新し、全話再取得が走ること・旧ファイル名が残らないこと（同じ話が2件に見えないこと）を確認する
- [ ] 5.3 短編作品をダウンロードし、本文とタイトルが正しく取得できることを確認する
- [ ] 5.4 R-18作品が引き続き取得できることを確認する（`over18` Cookie 経路の回帰確認）

## 6. ドキュメント同期

- [ ] 6.1 `docs/specs/maintenance/07-external-integrations.md` の INV-0116 の行参照を更新する
- [ ] 6.2 必要に応じて `TECH_DEBT_AUDIT.md` に「フィクスチャが手書きで実サイトのドリフトを検知できなかった」件の所見を追記する

## 7. 最終確認

- [ ] 7.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 7.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 7.3 `fvm flutter analyze`でリントを実行
- [ ] 7.4 `fvm flutter test`でテストを実行
