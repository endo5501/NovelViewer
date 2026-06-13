## 1. テスト先行（TDD: Red）

- [x] 1.1 `test/features/text_download/` に桁幅移行のテストファイルを追加（例: `episode_filename_pad_migration_test.dart`）。一時ディレクトリにエピソードファイルを配置して移行挙動を検証する形にする
- [x] 1.2 桁増加ケースのテスト: 99話分（`01_…99_`、pad=2）を置き、total=100 で移行 → `001_…099_` にリネームされ2桁ファイルが残らないことを assert（失敗を確認）
- [x] 1.3 桁減少ケースのテスト: `001_…100_`（pad=3）を置き、total=99 で移行 → `01_…99_` にリネームされることを assert
- [x] 1.4 残留ゴミ削除ケースのテスト: `newName`（正規）と別桁幅の重複ファイルが両方ある状態 → 重複のみ削除され正規ファイルは不変であることを assert
- [x] 1.5 冪等性のテスト: 既に現桁幅で揃っている状態 → rename/delete が発生しないことを assert
- [x] 1.6 タイトル変更ファイル非対象のテスト: 同一indexだが `safeName(title)` が異なるファイルは移行されず残ることを assert
- [x] 1.7 キャッシュ非変更のテスト: 移行後にスキップ判定が正しくヒットし、`episode_cache.db` に追加/変更/削除が起きないことを assert
- [x] 1.8 スキップ判定との結合テスト: 99→100境界で、移行後にエピソード1–99がスキップされ、新規100のみDLされる（`failedCount`/`skippedCount`/DL回数）ことを検証
- [x] 1.9 `fvm flutter test` で 1.2–1.8 が失敗することを確認（Red）。テストが正しいことを確認した段階でコミット

## 2. 実装（TDD: Green）

- [x] 2.1 `download_service.dart` に桁幅移行ヘルパーを実装（フォルダを1回 list、`^(\d+)_(.+)\.txt$` でパースして `(parsedIndex, restName)` を取得し、現index の各 `(i, title)` に対し `parsedIndex == i && restName == safeName(title) && name != newName` を一致条件とする）
- [x] 2.2 リネーム/削除の条件分岐を実装（`newName` 不在＋別桁幅一致→rename、`newName` 存在＋別桁幅一致→重複削除、それ以外→no-op）。正規 `newName` は決して削除しない
- [x] 2.3 `_downloadEpisodes` の `total` 確定後・エピソードループ前に移行パスを1回呼び出す（マルチページindex マージ後の total を使用）
- [x] 2.4 個々の rename/delete を try で囲み、失敗は `Logger('text_download').warning(...)` にとどめてDL全体は継続（当該話は従来どおり再DLにフォールバック）
- [x] 2.5 `fvm flutter test` で全テストがパスすることを確認（Green）

## 3. 最終確認

- [ ] 3.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 3.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 3.3 `fvm flutter analyze` でリントを実行
- [ ] 3.4 `fvm flutter test` でテストを実行
