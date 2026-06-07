## Why

NovelViewer は現在「なろう」「カクヨム」「青空文庫」からの小説ダウンロードに対応しているが、二次創作小説の主要サイトである「ハーメルン」(syosetu.org) には未対応である。ハーメルンの作品を閲覧したいユーザーは別手段でテキストを用意する必要があり、本アプリ内で完結できない。既存のサイトアダプタは `NovelSite` 抽象クラスを実装してレジストリに登録するだけのプラグイン構造になっており、ハーメルン追加の限界コストは小さい。

## What Changes

- ハーメルン (syosetu.org) の小説をダウンロード対象として認識・取得できるようにする新サイトアダプタ `HamelnSite` を追加する。
- `NovelSiteRegistry` に `HamelnSite` を登録し、`https://syosetu.org/novel/<id>/` 形式のURLを既存の `findSite` 経路でルーティングできるようにする。
- 目次ページ（テーブル形式・章見出し付き）をパースして全話をフラットなエピソード一覧として取得する。リンクのファイル番号 (`./N.html`) を正としてエピソードURLを構成し、表示話数のズレに依存しない。
- 本文ページの `#honbun` から本文を抽出する（前書き `#maegaki`・後書き `#atogaki` は本文に含めない）。
- 一話完結（短編）作品は、目次行が無く `#honbun` が存在するケースとして検出し、`bodyContent` として扱う。
- R-18 作品も特別な処理（年齢確認 Cookie 等）なしで取得できる（実調査で確認済み。後述）。
- 追加はUI非破壊。`download_dialog` の「対応サイト判定」に新たな対応サイトが1つ増えるのみで、既存サイトの挙動・データには影響しない。

## Capabilities

### New Capabilities
- `hameln-download`: ハーメルン (syosetu.org) からの小説ダウンロード対応。URL認識・小説ID抽出・URL正規化・目次パース（章フラット化／ファイル番号ベースのURL構成／更新日抽出）・本文抽出・短編判定・サイト種別 (`hameln`) を定義する。

### Modified Capabilities
（なし。既存の `text-download` の共通インターフェースや他サイトの要件は変更しない。）

## Impact

- **新規コード**: `lib/features/text_download/data/sites/hameln_site.dart`（`NovelSite` 実装）。
- **変更コード**: `lib/features/text_download/data/sites/novel_site.dart` の `NovelSiteRegistry._sites` に `HamelnSite()` を1行追加。
- **新規テスト**: `test/features/text_download/hameln_site_test.dart`（HTMLフィクスチャによる `canHandle` / `extractNovelId` / `parseIndex` / `parseEpisode` のテスト。短編フィクスチャ1件を含む）。
- **依存パッケージ**: 追加なし（既存の `http` / `html` パッケージのみ。青空のような Shift-JIS デコードは不要で UTF-8 のまま）。
- **i18n**: 「対応サイト」表示等に文言追加が必要な場合のみ既存の言語リソースへ追記（破壊的変更なし）。
