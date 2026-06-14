# Tasks

## 1. テストの書き換え（TDD）

- [ ] 1.1 `/test-driven-development` スキルを使用して着手する
- [ ] 1.2 `test/shared/database/per_folder_db_registry_test.dart` の「normalizes the folder key so equivalent paths share one handle」を、`package:path` のホストOSセパレータ（`p.join` / `p.separator`）で基準パスと `..` を含む等価な冗長パスを構築する方式に書き換える
- [ ] 1.3 同ファイルの「closeAll uses the normalized key to reach handles」を、同様にホストOSセパレータで冗長パスを構築する方式に書き換える
- [ ] 1.4 `C:\...` 等のWindows固有絶対パス・OS固有セパレータのハードコードが当該テストから除去されていることを確認する
- [ ] 1.5 production コード（`lib/shared/database/folder_db_key.dart` ほか）を変更していないことを確認する

## 2. 検証

- [ ] 2.1 macOS で当該テストを実行し、2件の `[E]` が解消され Pass することを確認する
- [ ] 2.2 （可能なら）Windows でも当該テストが引き続き Pass することを確認する

## 3. 最終確認

- [ ] 3.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 3.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 3.3 `fvm flutter analyze`でリントを実行
- [ ] 3.4 `fvm flutter test`でテストを実行
