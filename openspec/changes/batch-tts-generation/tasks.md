## 1. TTS Audio Database（データ層）

- [x] 1.1 `TtsAudioDatabase` クラスを作成（`EpisodeCacheDatabase` パターンに倣い、`tts_audio.db` の初期化・オープン・クローズ）
- [x] 1.2 `tts_episodes` テーブル作成（id, file_name, sample_rate, status, ref_wav_path, created_at, updated_at）
- [x] 1.3 `tts_segments` テーブル作成（id, episode_id, segment_index, text, text_offset, text_length, audio_data BLOB, sample_count, ref_wav_path, created_at）＋ユニークインデックス＋外部キー CASCADE
- [x] 1.4 `TtsAudioRepository` クラスを作成（createEpisode, insertSegment, findEpisodeByFileName, getSegments, findSegmentByOffset, getSegmentCount, deleteEpisode）

## 2. TTS Batch Generation（生成コントローラ）

- [x] 2.1 `TtsGenerationController` クラスを作成（テキスト分割→Isolate合成→WAVバイト変換→DB保存の逐次パイプライン）
- [x] 2.2 生成進捗の通知機能を実装（Riverpodプロバイダ: current/total）
- [x] 2.3 キャンセル機能を実装（Isolate停止、エピソード＋セグメント削除）
- [x] 2.4 既存データ削除→再生成のフローを実装
- [x] 2.5 合成エラー時のクリーンアップ処理を実装

## 3. TTS Stored Playback（再生コントローラ）

- [ ] 3.1 `TtsAudioPlayer` 抽象に `pause()` メソッドを追加、`JustAudioPlayer` に実装
- [ ] 3.2 `TtsStoredPlayerController` クラスを作成（DB→WAV BLOB取得→一時ファイル書き出し→再生の逐次パイプライン）
- [ ] 3.3 次セグメントの先読み（DB BLOB読み込み＋一時ファイル書き出し）を実装
- [ ] 3.4 一時停止/再開機能を実装
- [ ] 3.5 停止機能を実装（位置リセット、ハイライトクリア、一時ファイル削除）
- [ ] 3.6 テキスト位置指定再生を実装（text_offsetからセグメント特定→そのセグメントから再生開始）
- [ ] 3.7 ハイライト連動を実装（既存の `ttsHighlightRangeProvider` を使用）
- [ ] 3.8 自動ページ送りとの連携を確認（既存メカニズムの再利用）

## 4. 状態管理プロバイダ（Provider層）

- [ ] 4.1 `TtsAudioState` (none/generating/ready) のプロバイダを新設
- [ ] 4.2 `TtsGenerationProgress` (current/total) のプロバイダを新設
- [ ] 4.3 `TtsPlaybackState` を変更（loading を削除、paused を追加: stopped/playing/paused）
- [ ] 4.4 `TtsAudioDatabase` / `TtsAudioRepository` のプロバイダを作成（小説フォルダパス連動）
- [ ] 4.5 `TtsGenerationController` / `TtsStoredPlayerController` のファクトリプロバイダを作成

## 5. UI変更（TextViewerPanel）

- [ ] 5.1 状態に応じたボタン表示切り替えを実装（none→生成ボタン、generating→進捗バー＋キャンセル、ready→再生＋削除、playing→一時停止＋停止、paused→再開＋停止）
- [ ] 5.2 進捗バーUIを実装（LinearProgressIndicator + "N/M文" テキスト）
- [ ] 5.3 削除ボタンの処理を実装（エピソード音声データの削除）
- [ ] 5.4 エピソード切り替え時の生成停止/再生停止を実装
- [ ] 5.5 エピソード表示時の音声状態初期チェック（DBからstatus確認→プロバイダ更新）

## 6. 旧コード削除

- [ ] 6.1 `TtsPlaybackController` クラスを削除
- [ ] 6.2 `TtsFileCleaner` 抽象と `FileCleanerImpl` を削除
- [ ] 6.3 `WavWriterAdapter` を削除
- [ ] 6.4 `ttsControllerFactoryProvider` を削除
- [ ] 6.5 旧 `TtsPlaybackController` 関連のテストを削除
- [ ] 6.6 ページ内操作（矢印キー、スワイプ、マウスホイール）での再生停止ロジックを削除（同一エピソード内では停止しない）

## 7. 最終確認

- [ ] 7.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [ ] 7.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 7.3 `fvm flutter analyze`でリントを実行
- [ ] 7.4 `fvm flutter test`でテストを実行
