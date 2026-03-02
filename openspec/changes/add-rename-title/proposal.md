## Why

現在、小説のタイトルはダウンロード時にWebサイトから取得した値がDBに保存され、以降ユーザーが変更する手段がない。Webサイト側のタイトル変更やユーザーの好みによるカスタマイズに対応するため、タイトル変更機能が必要。

## What Changes

- ファイルブラウザのコンテキストメニュー（右クリック）に「タイトル変更」オプションを追加
- タイトル変更用のダイアログUIを新設（現在のタイトルを表示し、新しいタイトルを入力）
- NovelRepositoryにタイトル更新メソッドを追加
- タイトル変更後、ファイルブラウザのUI表示を自動更新

## Capabilities

### New Capabilities
- `novel-rename-title`: 小説のタイトルをユーザーが任意に変更できる機能（コンテキストメニュー、ダイアログUI、DB更新）

### Modified Capabilities
- `file-browser`: コンテキストメニューに「タイトル変更」オプションを追加
- `novel-metadata-db`: タイトル単体を更新するメソッドを追加

## Impact

- `lib/features/file_browser/presentation/file_browser_panel.dart` - コンテキストメニューに項目追加
- `lib/features/novel_metadata_db/data/novel_repository.dart` - タイトル更新メソッド追加
- `lib/features/novel_metadata_db/data/novel_database.dart` - 影響なし（スキーマ変更不要）
- 依存パッケージの追加なし
