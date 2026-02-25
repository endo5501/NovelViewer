## Why

現在のTTS機能は「全セグメント生成完了後に再生」という2段階フローで、生成完了まで音声を聴けない。また、途中キャンセル時に生成済みデータが全て削除されるため、再実行時に最初からやり直しになる。生成と再生をパイプライン化し、生成済みデータを保持することで、即座にフィードバックが得られ、中断・再開が自然に行えるようになる。

## What Changes

- 生成したセグメントを即座に再生し、再生中に次のセグメントを先行生成するストリーミングパイプラインを導入
- 途中停止時に生成済みセグメントをDBに保持（削除しない）し、エピソードステータスを `partial` に設定
- 再開時は保存済みセグメントを再生しつつ、未生成分に到達したら生成+再生を継続
- テキスト変更検出（ハッシュ比較）を追加し、元テキストが変更された場合は既存データを破棄して最初から生成
- 再生が生成に追いついた場合はローディング表示を行う

## Capabilities

### New Capabilities

- `tts-streaming-pipeline`: 生成と再生を統合するストリーミングコントローラー。保存済みセグメント再生→未生成分の生成+再生の切り替え、生成待ちのローディング表示、テキスト変更検出によるデータ無効化を担当

### Modified Capabilities

- `tts-batch-generation`: キャンセル時のデータ削除をやめ、生成済みセグメントを保持する。エピソードステータスに `partial` を追加。セグメント単位の生成完了通知を追加
- `tts-audio-storage`: `tts_episodes` テーブルに `text_hash` カラムを追加。ステータス値に `partial` を追加。保存済みセグメント数取得メソッドの活用
- `tts-stored-playback`: ストリーミングパイプラインとの統合。`partial` / `completed` 両方のエピソードを再生可能にする

## Impact

- **コード**: `TtsGenerationController`, `TtsStoredPlayerController` を統合した新コントローラー `TtsStreamingController` を追加。既存コントローラーは段階的に置き換え
- **DB**: `tts_episodes` テーブルに `text_hash TEXT` カラム追加（マイグレーション）
- **状態管理**: `TtsAudioState` enum は変更なし（`none | generating | ready`）。`partial` はDB内部ステータスとしてのみ使用し、UI上は `ready` として扱う
- **UI**: `TextViewerPanel` の生成/再生ボタンの振る舞い変更。生成待ち時のローディング表示追加
