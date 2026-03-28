## Why

TTS音声データ（BLOB）を削除してもSQLiteのDBファイルサイズが縮小しない。SQLiteはDELETE時にページを「空き」としてマークするだけで、OSにディスク領域を返却しないため。音声BLOBは大きい（10秒 ≈ 480KB）ため、削除後もファイルが肥大化したままになるのはユーザーにとって問題。

## What Changes

- `tts_audio.db` に `auto_vacuum = INCREMENTAL` を設定し、削除後にディスク領域を回収可能にする
- DB接続時に `PRAGMA auto_vacuum = INCREMENTAL` を設定
- 既存DBに対しては一度だけ `VACUUM` を実行して `INCREMENTAL` モードに移行
- エピソード削除後に `PRAGMA incremental_vacuum(0)` を呼び出して空きページを回収

## Capabilities

### New Capabilities

（なし — 既存機能の改善）

### Modified Capabilities

- `tts-audio-storage`: DB初期化時にauto_vacuum=INCREMENTALを設定し、削除操作後にincremental_vacuumで領域回収する要件を追加

## Impact

- `tts_audio_database.dart`: onConfigure、onCreate、onUpgradeに変更
- `tts_audio_repository.dart`: 削除メソッドにincremental_vacuum呼び出しを追加
- 既存DBは初回接続時にVACUUMで移行（一時的にDB容量の2倍のディスク領域が必要）
