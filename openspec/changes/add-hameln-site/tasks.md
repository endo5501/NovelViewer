## 1. フィクスチャ採取

- [x] 1.1 複数話作品の目次HTMLを採取（例: `https://syosetu.org/novel/402955/`）。章見出し・表示番号とファイル番号がズレた行・更新日（`(改)`含む行）を含むものを保存
- [x] 1.2 本文ページHTMLを採取（`#honbun`・`#maegaki`・`#atogaki` を含むもの）
- [x] 1.3 一話完結（短編）作品の目次/本文HTMLを1件採取（`#honbun` あり・目次行なし）。見つからなければ調査して代替を確保（実例: ID=415221 を確認）
- [x] 1.4 採取HTMLを `test/features/text_download/` 配下のフィクスチャとして配置（既存テストのインラインHTML文字列方式に合わせる）

## 2. テスト作成（テストファースト）

- [x] 2.1 `test/features/text_download/hameln_site_test.dart` を新規作成
- [x] 2.2 `canHandle` のテスト: `syosetu.org/novel/<id>/` とエピソードURLを受理、トップページを拒否、`ncode.syosetu.com`(なろう)を非該当とする
- [x] 2.3 `extractNovelId` のテスト: 目次URL・エピソードURLの双方から `402955` を抽出
- [x] 2.4 `normalizeUrl` のテスト: エピソードURL→ `https://syosetu.org/novel/<id>/`、目次URLは保持
- [x] 2.5 `parseIndex` のテスト: title抽出、章をまたいだフラット化、`index` の1始まり連番、URLが `href` のファイル番号（表示番号ではない）から構成されること
- [x] 2.6 `parseIndex` のテスト: `updatedAt` が `<NOBR>` 生テキストのまま格納され `(改)` が保持されること
- [x] 2.7 `parseIndex` のテスト: 短編は `episodes` 空・`bodyContent` あり、複数話は `bodyContent` なし
- [x] 2.8 `parseEpisode` のテスト: `#honbun` の本文を改行保持で抽出し、`#maegaki`/`#atogaki` を含まないこと
- [x] 2.9 `NovelSiteRegistry.findSite` がハーメルンURLで `HamelnSite` を返すテスト（`novel_site_test.dart` への追記でも可）
- [x] 2.10 `fvm flutter test` を実行し、テストが期待どおり失敗（未実装）することを確認してコミット

## 3. 実装

- [x] 3.1 `lib/features/text_download/data/sites/hameln_site.dart` を作成し `NovelSite` を実装（`siteType='hameln'`、`decodeBody`/`requestHeaders` は基底デフォルト）
- [x] 3.2 `canHandle` / `extractNovelId` / `normalizeUrl` を実装
- [x] 3.3 `parseIndex` を実装: 目次テーブルを走査、章見出し行を無視してフラット化、`href` からURL構成・出現順で `index` 連番、`<NOBR>` から `updatedAt` を生格納
- [x] 3.4 `parseIndex` の短編フォールバック実装: 目次行が無く `#honbun` があれば `parseEpisode(html)` を `bodyContent` に
- [x] 3.5 `parseEpisode` を実装: `#honbun` の子要素を `blockToText` で `\n` 連結（`NarouSite` と同型）。`#maegaki`/`#atogaki` は除外
- [x] 3.6 `lib/features/text_download/data/sites/novel_site.dart` の `NovelSiteRegistry._sites` に `HamelnSite()` を追加
- [x] 3.7 `fvm flutter test` を実行し、2章のテストが全てパスすることを確認

## 4. 統合確認

- [x] 4.1 i18n リソース `download_unsupportedSiteError`（ja/en/zh）へハーメルンを追記し、l10nを再生成
- [x] 4.2 実際のsyosetu.org HTML（複数話402955・短編415221・本文・R-18構造）でパーサを検証。title/連番/href由来URL/(改)保持/短編bodyContent/honbun限定を確認（GUIからの手動DLはユーザー確認に委ねる）
- [x] 4.3 242話の長編(402124)で目次が単一ページ・ページングなし（`nextPageUrl` null）を確認。`nextPageUrl` 対応は本変更スコープ外と判断

## 5. 最終確認

- [ ] 5.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 5.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 5.3 `fvm flutter analyze`でリントを実行
- [ ] 5.4 `fvm flutter test`でテストを実行
