## 1. DB初期化の変更（TtsAudioDatabase）

- [x] 1.1 `_onConfigure` に `PRAGMA auto_vacuum = INCREMENTAL` を追加
- [x] 1.2 `_open` メソッドにauto_vacuum移行処理を追加（`_migrateAutoVacuum`: モード確認→PRAGMA設定→VACUUM）
  - 注: `onUpgrade`はトランザクション内で実行されるためVACUUMできない。`_open`後に実行する方式に変更。
  - `_databaseVersion`の変更は不要（スキーマ変更なし）。

## 2. 削除後のディスク領域回収（TtsAudioRepository）

- [x] 2.1 `deleteEpisode` の後に `PRAGMA incremental_vacuum(0)` を実行する処理を追加

## 3. テスト

- [x] 3.1 新規DB作成時に `auto_vacuum = INCREMENTAL` が設定されていることを検証するテスト
- [x] 3.2 既存DB（auto_vacuumなし）からの移行で `auto_vacuum = INCREMENTAL` が有効になることを検証するテスト
- [x] 3.3 `deleteEpisode` 後にDBファイルサイズが縮小することを検証するテスト

## 4. 最終確認

- [x] 4.1 simplifyスキルを使用してコードレビューを実施
- [x] 4.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 4.3 `fvm flutter analyze`でリントを実行
- [x] 4.4 `fvm flutter test`でテストを実行
