## Why

ファイルブラウザでエピソード一覧を表示した際、各エピソードのTTS読み上げデータが生成済みか未生成か途中かが視覚的にわからない。ユーザはテキストビューアで個別にファイルを開かないと状態を確認できず、効率が悪い。

## What Changes

- `TtsAudioRepository` に全エピソードのTTS状態を一括取得するメソッドを追加
- `DirectoryContents` にTTS状態マップを追加し、`directoryContentsProvider` でDB問い合わせを統合
- `FileBrowserPanel` のエピソードListTileの `trailing` にTTS状態アイコン（生成済み: check_circle緑、一部生成: pie_chartオレンジ、未生成: 非表示）を表示

## Capabilities

### New Capabilities
- `tts-status-display`: ファイルブラウザのエピソード一覧にTTS読み上げデータの生成状態をアイコンで表示する機能

### Modified Capabilities
- `file-browser`: DirectoryContentsにTTS状態マップを追加し、エピソードListTileにtrailingアイコンを表示
- `tts-audio-storage`: 全エピソードのTTS状態を一括取得するリポジトリメソッドを追加

## Impact

- **コード**: `TtsAudioRepository`, `DirectoryContents`, `directoryContentsProvider`, `FileBrowserPanel` の変更
- **依存関係**: ファイルブラウザ機能がTTSデータベースに依存するようになる（DBが存在しない場合はフォールバックで空マップ）
- **パフォーマンス**: ディレクトリ変更時に1回のSQLiteクエリが追加されるが、ローカルDBのため影響は軽微
