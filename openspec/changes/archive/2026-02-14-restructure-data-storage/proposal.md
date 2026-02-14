## Why

現在、ダウンロードした小説はタイトル名をフォルダ名として管理しているが、小説のタイトルは頻繁に変更されるため、フォルダ名との不整合が発生する。また、macOSのバンドルIDが `com.example.novelViewer` のままであり、データ保存パスに不適切な識別子が含まれている。データの保存構造とアプリ識別子を見直し、安定したデータ管理基盤を構築する。

## What Changes

- **BREAKING** 小説の保存フォルダをタイトル名ベースからサイト固有ID（なろうの `ncode`、カクヨムの作品ID）ベースに変更
- **BREAKING** SQLiteデータベースを導入し、小説のメタデータ（ID・タイトル・サイト情報など）を管理
- **BREAKING** macOSバンドルIDを `com.example.novelViewer` から `com.endo5501.novelViewer` に変更
- ファイルブラウザがフォルダ名ではなくDBから取得したタイトル名で小説を表示するよう変更
- ダウンロードサービスがID ベースのフォルダに保存し、メタデータをDBに登録するよう変更

## Capabilities

### New Capabilities
- `novel-metadata-db`: SQLiteデータベースによる小説メタデータ管理。小説ID・タイトル・サイト種別・URL・ダウンロード日時などを保持し、IDベースのフォルダ構造と表示用タイトルを紐付ける

### Modified Capabilities
- `text-download`: ダウンロード先フォルダをタイトル名からIDベースに変更し、ダウンロード完了時にメタデータDBへ登録する
- `file-browser`: フォルダ名の直接表示からDBベースのタイトル表示に変更し、IDフォルダ内のファイルを閲覧可能にする

## Impact

- **依存パッケージ追加**: `sqflite` または `drift` などのSQLiteパッケージが必要
- **データマイグレーション**: 既存のタイトル名フォルダからIDフォルダへの移行が必要（初回起動時のマイグレーション処理）
- **macOS設定変更**: `AppInfo.xcconfig` のバンドルID変更により、既存インストールとは別アプリとして認識される可能性がある
- **影響ファイル**:
  - `lib/features/text_download/data/download_service.dart` - 保存先ロジック変更
  - `lib/features/text_download/data/novel_library_service.dart` - ライブラリ管理変更
  - `lib/features/file_browser/data/file_system_service.dart` - ファイル探索ロジック変更
  - `lib/features/file_browser/presentation/file_browser_panel.dart` - 表示ロジック変更
  - `lib/features/text_download/data/sites/novel_site.dart` - IDの取得インターフェース追加
  - `macos/Runner/Configs/AppInfo.xcconfig` - バンドルID変更
  - `lib/main.dart` - DB初期化処理の追加
