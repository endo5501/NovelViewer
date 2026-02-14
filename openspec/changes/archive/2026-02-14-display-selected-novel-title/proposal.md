## Why

現在、AppBarのタイトルは常に「NovelViewer」と表示されており、どの小説を閲覧中かが一目でわからない。選択中の小説タイトルをAppBarに表示することで、ユーザーが現在の閲覧対象を即座に把握できるようにする。

## What Changes

- AppBarのタイトルを動的に変更し、選択中の小説タイトルを表示する
- 小説が未選択の場合（ライブラリルート表示時）は従来通り「NovelViewer」を表示する
- 現在のディレクトリから選択中の小説を特定するためのProviderを追加する

## Capabilities

### New Capabilities

- `app-title-display`: AppBarのタイトル表示を動的に制御する機能。現在のディレクトリ状態と小説メタデータから適切なタイトルを導出し表示する。

### Modified Capabilities

（なし）

## Impact

- `lib/home_screen.dart` - AppBarのタイトル表示部分の変更
- `lib/features/file_browser/providers/` - 選択中の小説を特定するProviderの追加
- 既存のProvider（`currentDirectoryProvider`, `allNovelsProvider`）を参照するが、変更はしない
