## 1. テスト基盤（フィクスチャ・先行失敗テスト / TDD: Red）

- [x] 1.1 `test/fixtures/text_download/` に各アダプタの**目次ページ**サニタイズ済み実HTMLフィクスチャを追加する: `narou_index_valid.html` / `narou_index_drifted.html`（セレクタ総外し）/ `kakuyomu_index_valid.html` / `hameln_index_valid.html` / `hameln_index_drifted.html` / `aozora_index_valid.html`
- [x] 1.2 F118: `download_service_test.dart`（または新規 `empty_index_guard_test.dart`）に、目次1ページ目が `episodes.isEmpty && bodyContent == null` のとき `downloadNovel` が `EmptyIndexException` を投げ、**フォルダを作らない**ことを検証する失敗テストを追加（drifted フィクスチャ＋MockClient使用）。Red を確認
- [x] 1.3 F118: 短編（`bodyContent` 非null・`episodes` 空）と Aozora index が `EmptyIndexException` を投げず従来どおり短編DLされる回帰テストを追加
- [x] 1.4 F119: `url_validation_test.dart` に host 偽装（`https://kakuyomu.jp.evil.com/works/123` → `findSite==null`）・非HTTPS（`http://kakuyomu.jp/works/123` → null）・works パス無し（`https://kakuyomu.jp/` → false）・正規ホスト（`kakuyomu.jp` / `www.kakuyomu.jp` → 解決）の失敗/成功テストを追加。Red を確認
- [x] 1.5 F120: UA 優先順位テストを追加（`requestHeaders` が `User-Agent` を返すサイト=Hameln 相当で、送信ヘッダの `User-Agent` がサイト指定値になる／返さないサイトで既定 UA になる）。MockClient で実際に送信されたヘッダを捕捉して検証。Red を確認
- [x] 1.6 既存の関連テスト（`url_validation_test` / `download_service_test` / `kakuyomu_site_test` / `hameln_site_test` / `narou_site_test` / `aozora_site_test`）が現状緑であることを確認してから着手

## 2. F118 目次全滅ガード（実装: Green）

- [x] 2.1 `lib/features/text_download/data/` に `EmptyIndexException`（`Uri url` を保持、診断用メッセージ付き）を新設する（`download_service.dart` 内 or 同 feature の例外置き場）
- [x] 2.2 `DownloadService.downloadNovel` の `parseIndex` 直後・**`createNovelDirectory` の前**に下流ガード `if (novelIndex.episodes.isEmpty && novelIndex.bodyContent == null) throw EmptyIndexException(normalizedUrl);` を追加
- [x] 2.3 ガード送出時に `Logger('text_download')` で WARNING を出す（診断可能性の担保）
- [x] 2.4 1.2 / 1.3 のテストが緑になることを確認

## 3. F118 呼び出し側（provider / UI）での error 表面化

- [x] 3.1 `text_download_providers.dart` で `EmptyIndexException` を捕捉し、目次1ページ目取得失敗と同じ error 状態経路へ流す（未処理例外にしない）
- [x] 3.2 ユーザ向け文言の方針を決定（既存の汎用ダウンロードエラー文言に載せる or 専用文言）。専用文言を追加する場合は `.arb`（en/ja/zh）にフルパリティで追加し `gen-l10n` の欠落警告ゼロを確認
- [x] 3.3 provider/dialog レベルで「空目次→error 表示」を検証するテストを追加（既存の `download_provider_state_test.dart` / `download_dialog_test.dart` のパターンに倣う）

## 4. F119 ホスト/スキーム検証の一本化（実装: Green）

- [x] 4.1 `NovelSiteRegistry.findSite` に `if (url.scheme != 'https') return null;` を追加（全アダプタ一括のHTTPS限定）
- [x] 4.2 `KakuyomuSite.canHandle` を厳密ホスト集合 `{'kakuyomu.jp', 'www.kakuyomu.jp'}` ＋ `/works/<id>` パスチェックへ変更（`url.host.contains(...)` を撤去）。`_allowedHosts` static を他アダプタと同形で定義
- [x] 4.3 1.4 のテストが緑になることを確認。既存の正規URL受理テスト（Narou/novel18/Aozora/Hameln）が回帰しないことを確認

## 5. F120 User-Agent 優先順位の固定（実装: Green）

- [x] 5.1 `DownloadService._fetchPageResponse` の UA マージ（現行 `{'User-Agent': _userAgent, ...siteHeaders}` の spread 後勝ち）を維持しつつ、優先順位がテストで固定されている状態にする（必要ならレビュー指摘に応じて明示的マージへ書き下し可）
- [x] 5.2 1.5 のテストが緑になることを確認

## 6. ドキュメント同期

- [x] 6.1 本change完了時に `TECH_DEBT_AUDIT.md` の F118 / F119 / F120 / F122(一部) に対応状況を追記（解決方針・change名）。後続 `add-scraper-fetch-retry`（F121）への参照も残す

## 7. 最終確認

- [x] 7.1 code-reviewスキルを使用してコードレビューを実施
- [x] 7.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 7.3 `fvm flutter analyze`でリントを実行
- [x] 7.4 `fvm flutter test`でテストを実行
