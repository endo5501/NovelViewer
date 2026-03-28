## Context

`tts_audio.db` はSQLiteデータベースで、TTS音声をBLOBとして格納している。SQLiteのデフォルト動作ではDELETE後にファイルサイズが縮小しない（空きページが再利用可能としてマークされるだけ）。現在、VACUUMやauto_vacuumの設定は行われていない。

関連ファイル：
- `lib/features/tts/data/tts_audio_database.dart` — DB初期化・スキーマ管理
- `lib/features/tts/data/tts_audio_repository.dart` — CRUD操作

## Goals / Non-Goals

**Goals:**
- TTS音声データ削除後にDBファイルのディスク領域を回収する
- 既存DBを自動的にINCREMENTALモードへ移行する

**Non-Goals:**
- DB格納方式の変更（BLOB→ファイル等）
- 削除操作のUI変更

## Decisions

### 1. auto_vacuum = INCREMENTAL を採用

**選択肢：**
| 方式 | メリット | デメリット |
|------|---------|-----------|
| 手動VACUUM | シンプル | DB全体コピーで遅い、一時的に2倍の容量が必要 |
| auto_vacuum = FULL | 自動で回収 | 毎回のDELETEが遅くなる |
| **auto_vacuum = INCREMENTAL** | **必要時のみ回収、通常の読み書きに影響なし** | **incremental_vacuum呼び出しが必要** |

**理由：** INCREMENTALは通常の読み書き性能に影響を与えず、回収タイミングを制御できる。

### 2. onConfigureでPRAGMA設定、onUpgradeで既存DB移行

- `onConfigure`: `PRAGMA auto_vacuum = INCREMENTAL` を設定（新規DB作成時に反映）
- `onUpgrade` (version 3→4): 既存DBに対して `PRAGMA auto_vacuum = INCREMENTAL` + `VACUUM` を実行して移行

**理由：** onConfigureはDB接続のたびに呼ばれるが、auto_vacuumのPRAGMAはDB作成時にのみ効果がある。既存DBの移行にはVACUUMが必要なので、onUpgradeで一度だけ実行する。

### 3. deleteEpisode後にincremental_vacuumを実行

`TtsAudioRepository.deleteEpisode` の後に `PRAGMA incremental_vacuum(0)` を呼ぶ。`0` は全空きページを回収する。

**理由：** エピソード削除はBLOBの大量解放を伴うため、ここで回収するのが最も効果的。個別セグメント削除（`deleteSegment`）は小規模なのでvacuumは不要。

## Risks / Trade-offs

- **既存DB移行時のVACUUM** → 大きなDBでは一時的にディスク使用量が増加し、時間がかかる。ただし一度きりの操作であり、ユーザー操作をブロックしない（DB初回オープン時に実行）。
- **incremental_vacuum(0)の実行時間** → 解放ページ数に比例するが、エピソード削除は頻繁な操作ではないため許容範囲。
