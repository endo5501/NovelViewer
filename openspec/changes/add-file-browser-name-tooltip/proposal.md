## Why

ファイルブラウザ（左カラム）はカラム幅が狭く、小説フォルダのタイトルやエピソードファイル名が `TextOverflow.ellipsis` で末尾を省略表示している。そのためフルネームを確認できず、似た名前の小説やファイルを見分けづらいという不便がある。マウスホバーでフルネームをポップアップ表示できれば、レイアウトを変えずにこの問題を解消できる。

## What Changes

- ファイルブラウザのフォルダタイル（`_buildDirectoryTile`）にツールチップを追加し、ホバー時にフォルダの表示名（`displayName`）のフルネームを表示する。
- ファイルブラウザのファイルタイル（`_buildFileTile`）にツールチップを追加し、ホバー時にファイル名（`name`）のフルネームを表示する。
- 表示には Flutter 標準の `Tooltip` を用いる（デスクトップではホバーで自動表示）。名前が省略されているかどうかに関わらず、ホバー時は常に表示する。
- 小説フォルダのツールチップ内容は表示名（`displayName`）のみとする（フォルダ名 `name` は併記しない）。

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `file-browser`: フォルダタイル・ファイルタイルのホバー時にフルネームをツールチップ表示する要件を追加する。

## Impact

- 影響コード: `lib/features/file_browser/presentation/file_browser_panel.dart`（`_buildDirectoryTile` / `_buildFileTile`）
- 既存の選択中ファイルタイルの装飾（`Container` でのラップ分岐）と共存させる必要がある。
- 依存追加なし（Flutter 標準 `Tooltip` を使用）。
- API・データモデル・永続化への変更なし。
