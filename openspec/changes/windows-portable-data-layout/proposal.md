## Why

Windows環境において、メタデータDB（novel_metadata.db）がカレントディレクトリ依存の `getDatabasesPath()` で配置され、テキストファイルが `C:\Users\<user>\Documents\NovelViewer` に配置されるため、データが分散しexeの起動方法次第でDBが見つからなくなるリスクがある。簡易ビューアツールとして、exeと同じフォルダにすべてのデータを配置するポータブル構成にする。

## What Changes

- Windows環境でのテキストファイル保存先を `getApplicationDocumentsDirectory()` から exe と同じディレクトリ基準に変更
- Windows環境でのメタデータDB保存先を `getDatabasesPath()` から exe と同じディレクトリ基準に変更
- macOS/Linux の動作は現状維持（変更なし）
- 既存データの自動マイグレーションは行わない（開発中のため手動対応）

## Capabilities

### New Capabilities

- `windows-portable-layout`: Windows環境でexeと同じディレクトリにDB・テキストファイルを配置するポータブルデータレイアウト

### Modified Capabilities

- `novel-metadata-db`: Windows環境でのDB配置パスが `getDatabasesPath()` から exe ディレクトリに変更
- `text-download`: Windows環境でのテキストファイル保存先が Documents フォルダから exe ディレクトリに変更

## Impact

- `lib/features/novel_metadata_db/data/novel_database.dart` — DB パス解決ロジックの変更
- `lib/features/text_download/data/novel_library_service.dart` — ライブラリパス解決ロジックの変更
- `lib/main.dart` — 初期化処理の変更（必要に応じて）
- `dart:io` の `Platform.resolvedExecutable` を使用してexeのディレクトリを取得
