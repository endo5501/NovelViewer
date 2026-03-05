## Why

NovelViewerは「小説家になろう」(ncode.syosetu.com) と「カクヨム」(kakuyomu.jp) に対応しているが、なろうの姉妹サイトであるノクターンノベルズ/ムーンライトノベルズ/ミッドナイトノベルズ (novel18.syosetu.com) には対応していない。コードレベルでは `canHandle` が `syosetu.com` を含むホストを検出するため URL自体は受け付けるが、`novel18.syosetu.com` は年齢確認ゲートウェイがあり、`over18=yes` Cookieを送信しないとHTTP 403エラーが返される。そのため、実際にはダウンロードに失敗する。

## What Changes

- `NovelSite` に `requestHeaders(Uri url)` メソッドを追加し、サイトごとに追加HTTPヘッダーを定義可能にする
- `NarouSite` で `novel18.syosetu.com` へのリクエスト時に `Cookie: over18=yes` ヘッダーを付与する
- `DownloadService` がリクエスト時にサイトの `requestHeaders` を使用するよう修正する
- ダウンロードダイアログのヒントテキストとエラーメッセージを更新する
- `novel18.syosetu.com` URLに対するテストカバレッジを追加する

## Capabilities

### New Capabilities

(なし - 既存のtext-download機能の拡張)

### Modified Capabilities

- `text-download`: novel18.syosetu.com (ノクターンノベルズ/ムーンライトノベルズ/ミッドナイトノベルズ) のURLに対して年齢確認Cookieを付与してダウンロード可能にし、UIテキストを更新する

## Impact

- `lib/features/text_download/data/sites/novel_site.dart`: `NovelSite` に `requestHeaders` メソッド追加
- `lib/features/text_download/data/sites/narou_site.dart`: novel18 URL向けの `requestHeaders` 実装
- `lib/features/text_download/data/download_service.dart`: リクエスト時に `site.requestHeaders` を使用
- `lib/features/text_download/presentation/download_dialog.dart`: ヒントテキストとエラーメッセージの更新
- `test/features/text_download/narou_site_test.dart`: novel18 URL関連テスト追加
- `test/features/text_download/download_service_test.dart`: requestHeaders統合テスト追加
