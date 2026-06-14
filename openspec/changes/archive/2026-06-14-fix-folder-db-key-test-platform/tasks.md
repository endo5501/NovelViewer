# Tasks

## 1. テストの書き換え（TDD）

- [x] 1.1 `/test-driven-development` スキルを使用して着手する
- [x] 1.2 `test/shared/database/per_folder_db_registry_test.dart` の「normalizes the folder key so equivalent paths share one handle」を、`package:path` のホストOSセパレータ（`p.join` / `p.separator`）で基準パスと `..` を含む等価な冗長パスを構築する方式に書き換える
- [x] 1.3 同ファイルの「closeAll uses the normalized key to reach handles」を、同様にホストOSセパレータで冗長パスを構築する方式に書き換える
- [x] 1.4 `C:\...` 等のWindows固有絶対パス・OS固有セパレータのハードコードが当該テストから除去されていることを確認する
- [x] 1.5 production コード（`lib/shared/database/folder_db_key.dart` ほか）を変更していないことを確認する

## 2. 検証

- [x] 2.1 macOS で当該テストを実行し、2件の `[E]` が解消され Pass することを確認する（全9テスト Pass）
- [ ] 2.2 （可能なら）Windows でも当該テストが引き続き Pass することを確認する（※この環境は macOS のため未実施。ホストセパレータ使用により Windows でも同義で成立する設計）

## 3. 最終確認

- [x] 3.1 code-reviewスキルを使用してコードレビューを実施（findings なし）
- [x] 3.2 codexスキルを使用して現在開発中のコードレビューを実施（指摘なし・OK）
- [x] 3.3 `fvm flutter analyze`でリントを実行（No issues found）
- [x] 3.4 `fvm flutter test`でテストを実行（+2120 ~8、失敗0）
