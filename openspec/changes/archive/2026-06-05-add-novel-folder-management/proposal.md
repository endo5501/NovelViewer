## Why

現在 NovelViewer はライブラリルート直下にフラット（深さ1）で小説フォルダ（`folder_name = siteType_novelId`）を保存する。小説が増えると一覧が縦に長くなり、ジャンルや状態（連載中／完結済みなど）で整理できず使いにくい。ユーザーが任意のフォルダ階層で小説を整理できるようにしたい。あわせて、ファイルブラウザの「↑（上のフォルダへ移動）」ボタンがライブラリルートを超えて NovelViewer フォルダの外へ出てしまうバグも修正する。

## What Changes

- **整理フォルダの作成**: ファイルブラウザの現在表示中ディレクトリに、新規の整理用フォルダ（organizational folder）を作成できる。フォルダ名の無効文字・重複をチェックする。
- **整理フォルダのリネーム**: 整理フォルダは実ディレクトリ名を変更する（`Directory.rename`）。一方、小説フォルダの「リネーム」は従来どおり表示タイトルのみ DB 更新で実フォルダ名は不変とする（`folder_name` が DB 紐付けの主キーのため）。対象により処理を分岐する。
- **移動（右クリックメニュー）**: 小説フォルダおよび整理フォルダを、ライブラリ内の別フォルダへ移動できる。移動先はライブラリ内のフォルダ階層を表示するツリー選択ダイアログで選ぶ（ライブラリ外は選択不可）。
- **整理フォルダの削除**: 空の整理フォルダのみ削除可能。中に小説や子フォルダが残っている場合は削除不可とし、先に中身を移動させる運用とする。
- **小説／整理フォルダの判別と階層対応表示**: フォルダの basename が `novels` テーブルの `folder_name` に一致するものを「小説フォルダ」、それ以外を「整理フォルダ」とする（深さ非依存）。これにより、入れ子になった小説でも任意の深さでタイトル表示・右クリックメニューが正しく出る。
- **↑ナビゲーションのルート境界修正** (**BREAKING** ではないがバグ修正): `currentDir == libraryPath` のとき↑ボタンを無効化し、ライブラリルートより上へ移動できないようにする。

スコープ外: ドラッグ&ドロップによる移動（将来拡張）。ダウンロード時のフォルダ指定（ダウンロード先は常にライブラリルート直下を維持）。

## Capabilities

### New Capabilities
- `novel-folder-management`: 整理フォルダの作成・リネーム・移動・削除、および小説フォルダの移動。小説フォルダと整理フォルダを `folder_name` の有無で判別する規約。移動先選択のためのライブラリ内フォルダツリー選択ダイアログ。移動時のエッジケース（自分自身・子孫への移動禁止、移動先同名衝突、開いている小説の移動時のDBハンドル整合）の扱い。

### Modified Capabilities
- `file-browser`: 「Subdirectory navigation」要件を階層対応に拡張する。(1) タイトル表示・右クリックコンテキストメニューを「ライブラリルート直下のみ」から「任意の深さの小説フォルダ」へ拡張する。(2) 親ディレクトリ移動の境界を「ファイルシステムのルート」から「ライブラリルート」へ変更し、ライブラリ外へ出られないようにする。

## Impact

- **コード**:
  - `lib/features/file_browser/presentation/file_browser_panel.dart`: ツールバー（↑ボタンの境界制御）、ディレクトリタイル（小説／整理で右クリックメニュー分岐、新規フォルダ作成UI）、`getParentDirectory` の境界対応。
  - `lib/features/file_browser/providers/file_browser_providers.dart`: `directoryContentsProvider`（任意深さでの小説判定・タイトル変換）、`selectedNovelTitleProvider`（basename ベースの小説判定）、`currentDirectoryProvider`（移動時のハンドル整合）。
  - `lib/features/file_browser/data/file_system_service.dart`: `createDirectory` / `renameDirectory` / `moveDirectory`（空チェック付き `deleteDirectory` 含む）など階層操作 API を追加。
  - 移動先ツリー選択ダイアログ用の新規 UI ウィジェット。
- **データ／DB**: スキーマ変更なし。`novels.folder_name`（葉のフォルダ名）を移動後も不変に保つことで、`metadata` / `summary` / `factCache` / `readingProgress` の紐付けとフォルダ内同居の TTS 音声DB（`tts_audio.db`）はそのまま維持される。
- **i18n**: 新規フォルダ作成・移動・整理フォルダ削除・各種エラー（同名衝突、空でないフォルダ削除、自分自身への移動など）用の文言を `app_localizations` に追加。
- **ダウンロード**: 変更なし（ダウンロード先は常にライブラリルート直下）。
