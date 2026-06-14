## Why

`per_folder_db_registry_test.dart` のパス正規化テスト2件が Windows 形式パス（`C:\lib\n1\..\n1`）を決め打ちしているため、macOS（POSIX）では `\` が区切りとして扱われず `..` が解決されずキーが一致せず、`[E]` で失敗する。production コード（`folderDbKey` = `p.normalize`）はプラットフォーム文脈で正規化する意図通りの実装であり、バグはテスト側にある。CI/開発を Windows と macOS の両方で回しているため、テストはどちらの OS でも同じ意図を検証できる必要がある。

## What Changes

- `test/shared/database/per_folder_db_registry_test.dart` の以下2テストを、ホストOSのパスセパレータで `..` を含む等価パスを組み立てる方式に書き換える:
  - 「normalizes the folder key so equivalent paths share one handle」
  - 「closeAll uses the normalized key to reach handles」
- これにより「等価な（`..` を含む冗長な）パスは同一キーに正規化され、同一ハンドルを共有する／`closeAll` が到達する」という意図を、Windows・macOS の双方で検証できるようにする。
- production コード（`lib/shared/database/folder_db_key.dart`）は変更しない（意図通りのプラットフォーム依存正規化を維持）。

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `novel-folder-management`: 既存要件「移動・削除時のデータベースハンドル整合」が定める `folderDbKey` 正規化の不変条件（パス区切りの綴り差があっても同一フォルダが同一ハンドルへ解決される）について、その検証テストが特定OS（Windows）のパス形式に依存せず、ホストOSのセパレータで構築した等価パスにより Windows・macOS の双方で同一意図を検証することを保証する要件を追加する。

本変更は production の正規化振る舞い自体は変えない。テストがプラットフォーム非依存に既存不変条件を正しく検証するようにするテスト品質の補強であり、`folderDbKey` の実装は変更しない。

## Impact

- 影響コード: `test/shared/database/per_folder_db_registry_test.dart`（テストのみ）
- 影響なし: `lib/shared/database/folder_db_key.dart` ほか production コード、API、依存関係
- 効果: macOS での `fvm flutter test` が2件のエラーを解消し、Windows でも引き続きパスする
