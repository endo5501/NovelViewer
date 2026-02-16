## Why

小説フォルダ内でダウンロードダイアログを開いてダウンロードを実行すると、新しい小説がその小説フォルダ内にネストして保存されてしまう。ダウンロード先は常にライブラリのルートディレクトリであるべき。原因は `DownloadDialog` が保存先として `currentDirectoryProvider`（現在表示中のディレクトリ）を使用しているため。

## What Changes

- ダウンロードダイアログの保存先を `currentDirectoryProvider` から `libraryPathProvider` に変更し、常にライブラリルートに保存されるようにする

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `text-download`: ダウンロード保存先が常にライブラリルートであることを要件として明示する

## Impact

- `lib/features/text_download/presentation/download_dialog.dart` - `_canStartDownload` と `_startDownload` で参照するプロバイダーを変更
- 既存のダウンロード機能のテストに影響する可能性あり
