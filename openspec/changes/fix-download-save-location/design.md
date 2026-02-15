## Context

`DownloadDialog` は保存先パスを `currentDirectoryProvider` から取得している。このプロバイダーはユーザーが閲覧中のディレクトリパスを保持するため、小説フォルダ内にいるときにダウンロードすると、小説がフォルダ内にネストして保存される。

`libraryPathProvider` はライブラリのルートパス（固定値）を保持しており、これが常にダウンロードの保存先として使用されるべき。

## Goals / Non-Goals

**Goals:**
- ダウンロードの保存先を常にライブラリルートにする
- 最小限の変更で修正する

**Non-Goals:**
- ダウンロード先をユーザーが選択できるようにする機能
- フォルダ構造の再編成

## Decisions

- `download_dialog.dart` の `_canStartDownload` と `_startDownload` で `currentDirectoryProvider` の代わりに `libraryPathProvider` を参照する
- `libraryPathProvider` はアプリ起動時に確実に初期化されるため、null チェックのロジックはそのまま維持する

## Risks / Trade-offs

- 変更は1ファイル・2箇所のみであり、リスクは低い
- `currentDirectoryProvider` を参照していた既存テストがあれば修正が必要
