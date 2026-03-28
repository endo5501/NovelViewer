## 1. DB初期化の変更（TtsAudioDatabase）

- [ ] 1.1 `_onConfigure` に `PRAGMA auto_vacuum = INCREMENTAL` を追加
- [ ] 1.2 `_databaseVersion` を 3 → 4 に更新
- [ ] 1.3 `_onUpgrade` に version 3→4 の移行処理を追加（`PRAGMA auto_vacuum = INCREMENTAL` + `VACUUM`）

## 2. 削除後のディスク領域回収（TtsAudioRepository）

- [ ] 2.1 `deleteEpisode` の後に `PRAGMA incremental_vacuum(0)` を実行する処理を追加

## 3. テスト

- [ ] 3.1 新規DB作成時に `auto_vacuum = INCREMENTAL` が設定されていることを検証するテスト
- [ ] 3.2 既存DB（version 3）からの移行で `auto_vacuum = INCREMENTAL` が有効になることを検証するテスト
- [ ] 3.3 `deleteEpisode` 後に `incremental_vacuum` が実行されることを検証するテスト

## 4. 最終確認

- [ ] 4.1 simplifyスキルを使用してコードレビューを実施
- [ ] 4.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 4.3 `fvm flutter analyze`でリントを実行
- [ ] 4.4 `fvm flutter test`でテストを実行
