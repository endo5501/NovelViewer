## Why

カクヨムの目次ページがクライアントサイドハイドレーション（`work-toc-v2`機能フラグ）に移行済みで、サーバHTMLには「最新7話プレビュー」分の`<a href="/episodes/...">`しか含まれない。完全な目次は`<script id="__NEXT_DATA__">`内のApollo stateにある。さらに先頭には「1話目から読む」というCTAボタンが第1話URLを指して存在するため、現在のDOMセレクタ実装では第1話のタイトルが「1話目から読む」に上書きされてしまう。

現状の二重バグ:
1. 78話ある作品で7話分しかダウンロードできない
2. ダウンロードした第1話のタイトルが「1話目から読む」になる

## What Changes

- **BREAKING（パーサ実装）** `KakuyomuSite.parseIndex` を `<a href="/episodes/...">` ベースから`<script id="__NEXT_DATA__">`の Apollo state ベースに全面書き直し
- DOMフォールバックは撤去（カクヨムの旧構造には戻らない前提、最大7話しか取れず混乱の元になるため）
- `Work.tableOfContentsV2` → `TableOfContentsChapter.episodeUnions` → `Episode` を順に辿り、章境界は無視してflat結合
- `Episode.title` を `title` フィールドから直接取得（CTAボタンに影響されない）
- `Episode.updatedAt` を Apollo state の `Episode.publishedAt` から設定
- `__NEXT_DATA__` が見つからない／構造が想定外の場合は `ArgumentError` を投げ、ログに残す
- `kakuyomu_site_test.dart` を `__NEXT_DATA__` 構造のフィクスチャで全面書き直し

## Capabilities

### New Capabilities
（なし）

### Modified Capabilities
- `text-download`: カクヨム目次の取得元を DOM の `<a>` タグから `__NEXT_DATA__` Apollo state に変更し、関連シナリオ（「Index page episode date extraction for Kakuyomu」など）を更新

## Impact

- **コード**: `lib/features/text_download/data/sites/kakuyomu_site.dart`（`parseIndex` の全面書き換え、`_titleSelectors` 削除）
- **テスト**: `test/features/text_download/kakuyomu_site_test.dart`（`parseIndex` 関連テストの全面書き直し、`parseEpisode` 関連テストは現状維持）
- **依存**: 追加なし。既存の `package:html` を継続使用しつつ、JSON抽出に `dart:convert` を使用
- **動作**:
  - 既存ユーザの観点では「ダウンロードできるエピソード数が増える」「第1話タイトルが正しくなる」という改善
  - 既にダウンロード済みのカクヨム小説を再ダウンロードすれば、不足エピソードが追加され、第1話タイトルが修正される（増分更新の仕組みは触らない）
- **スコープ外**: `parseEpisode`（本文取得）、`download_service.dart` のURL重複排除ロジック、章/部の見出しUI、有料エピソードの扱い
