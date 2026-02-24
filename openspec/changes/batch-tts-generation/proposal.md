## Why

現在のTTS読み上げは1文ずつリアルタイムに合成・再生するため、合成速度が再生速度に追いつかず待ち時間が発生し、ストレスの原因になっている。事前にページ全体の音声を生成・保存する方式に切り替えることで、再生時のストレスを解消し、将来の拡張（登場人物ごとの声色変更、1文単位の再生成）にも対応できる基盤を作る。

## What Changes

- **BREAKING**: 現行のリアルタイム合成＋再生パイプライン（`TtsPlaybackController`、prefetchロジック、一時ファイル管理）を削除
- 小説フォルダ内に専用 `tts_audio.db` を新設し、文単位のWAV音声をBLOBとして保存
- [読み上げ音声生成]ボタンによるバッチ音声生成機能を追加（進捗バー＋キャンセル対応）
- 生成済み音声の[再生]ボタンによるストレスフリーな再生（一時停止/再開、テキスト位置指定再生、ハイライト連動）
- 生成済み音声の削除機能

## Capabilities

### New Capabilities
- `tts-audio-storage`: TTS音声データのSQLite DB保存（tts_audio.db、エピソード・文単位のCRUD）
- `tts-batch-generation`: ページ全体の音声バッチ生成（進捗通知、キャンセル、Isolateでの合成）
- `tts-stored-playback`: DB保存済み音声の再生（一時停止/再開、位置指定再生、ハイライト連動）

### Modified Capabilities
- `tts-playback`: リアルタイム合成+再生パイプラインを削除し、バッチ生成・保存済み再生方式に置き換え。playback pipeline with prefetch、audio file management、playback controller lifecycleの要件を削除。

## Impact

- **削除対象コード**: `TtsPlaybackController`、prefetchロジック、一時WAVファイル管理、`TtsFileCleaner`
- **変更対象コード**: `TextViewerPanel`のTTSボタンUI、`ttsPlaybackStateProvider`の状態定義
- **再利用コード**: `TtsIsolate`/`TtsEngine`（合成エンジン）、`TextSegmenter`（文分割）、`WavWriter`（WAV構築）、`JustAudioPlayer`（再生）
- **新規依存**: `sqflite`（既存依存、追加不要）
- **DB**: 小説フォルダ内に `tts_audio.db` を新設（`tts_episodes`テーブル、`tts_segments`テーブル）
