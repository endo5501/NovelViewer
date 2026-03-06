## Why

NovelViewerのダウンロード機能は現在、なろう（ncode.syosetu.com / novel18.syosetu.com）とカクヨム（kakuyomu.jp）のみ対応している。青空文庫（aozora.gr.jp）は日本の著作権切れ文学作品の最大のアーカイブであり、対応することでユーザが古典文学作品もローカルで閲覧できるようになる。

## What Changes

- 青空文庫のHTML版作品ページ（例: `https://www.aozora.gr.jp/cards/XXXX/files/XXXXX_XXXXX.html`）からテキストをダウンロードする `AozoraSite` クラスを新規追加
- 青空文庫は単一ページ作品（エピソード分割なし）のため、short story パスで処理する
- タイトルはHTMLの `<title>` タグから取得する
- `NovelSiteRegistry` に `AozoraSite` を登録
- ダウンロードダイアログのUI表示テキストに青空文庫を追加

## Capabilities

### New Capabilities
- `aozora-bunko-download`: 青空文庫（Web版HTML）からのテキストダウンロード機能。URL判定、HTMLパース、テキスト抽出を含む。

### Modified Capabilities
- `text-download`: ダウンロードダイアログのUIテキスト（ヒントテキスト、エラーメッセージ）に青空文庫を追加

## Impact

- `lib/features/text_download/data/sites/` に `aozora_site.dart` を新規追加
- `lib/features/text_download/data/sites/novel_site.dart` の `NovelSiteRegistry` にAozoraSiteを登録
- ダウンロードダイアログのUIテキスト更新
- 新規依存パッケージは不要（既存の `html` パッケージで対応可能）
