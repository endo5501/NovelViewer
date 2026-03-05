## 1. NovelSite インターフェース拡張（TDD: テストファースト）

- [x] 1.1 `novel_site_test.dart` に `requestHeaders` のデフォルト実装テストを追加（空Mapを返すこと）
- [x] 1.2 `NovelSite` に `Map<String, String> requestHeaders(Uri url)` メソッドを追加（デフォルトで空Map）

## 2. NarouSite の requestHeaders 実装（TDD: テストファースト）

- [x] 2.1 `narou_site_test.dart` に `requestHeaders` テストを追加: `novel18.syosetu.com` の場合に `Cookie: over18=yes` を返すこと
- [x] 2.2 `narou_site_test.dart` に `requestHeaders` テストを追加: `ncode.syosetu.com` の場合に空Mapを返すこと
- [x] 2.3 `NarouSite.requestHeaders` を実装

## 3. DownloadService の requestHeaders 統合（TDD: テストファースト）

- [x] 3.1 `download_service_test.dart` に `_fetchPageResponse` がサイトの `requestHeaders` をマージするテストを追加
- [x] 3.2 `DownloadService` を修正: `downloadNovel` 内のリクエストでサイトの `requestHeaders` を使用

## 4. novel18 URL テストカバレッジ強化

- [x] 4.1 `narou_site_test.dart` に `novel18.syosetu.com` の `normalizeUrl` テストを追加
- [x] 4.2 `narou_site_test.dart` に `novel18.syosetu.com` の `parseIndex` テストを追加（baseUrlがnovel18の場合）

## 5. UIテキスト更新

- [x] 5.1 `download_dialog.dart` のヒントテキストを更新: `novel18.syosetu.com` を含める
- [x] 5.2 `download_dialog.dart` のエラーメッセージを更新: 姉妹サイトもサポート対象であることを明記

## 6. 最終確認

- [x] 6.1 simplifyスキルを使用してコードレビューを実施
- [x] 6.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 6.3 `fvm flutter analyze`でリントを実行
- [x] 6.4 `fvm flutter test`でテストを実行
