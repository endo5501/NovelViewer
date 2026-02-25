## 1. DBスキーマとマイグレーション

- [x] 1.1 `TtsAudioDatabase` に `text_hash TEXT` カラム追加のマイグレーション実装（ALTER TABLE、既存DB対応）
- [x] 1.2 `tts_episodes` テーブルの `status` に `'partial'` 値を許容するようコメント・ドキュメント更新
- [x] 1.3 マイグレーションのテスト（新規DB作成、既存DB更新の両方）

## 2. リポジトリ更新

- [x] 2.1 `TtsAudioRepository.createEpisode()` に `textHash` パラメータを追加
- [x] 2.2 `TtsAudioRepository.updateEpisodeStatus()` が `'partial'` ステータスを正しく設定できることを確認するテスト追加
- [x] 2.3 リポジトリの新規・変更メソッドのユニットテスト

## 3. TtsGenerationController の修正

- [x] 3.1 `cancel()` メソッドを修正：`deleteEpisode` ではなく `updateEpisodeStatus('partial')` を呼び出す
- [x] 3.2 `_cleanup()` メソッドを修正：エピソード削除を削除し、Isolate解放とサブスクリプションキャンセルのみ行う
- [x] 3.3 `start()` に `startSegmentIndex` パラメータを追加し、指定インデックスから生成を開始する機能を実装
- [x] 3.4 `onSegmentStored` コールバックを追加（セグメント保存完了時にインデックスを通知）
- [x] 3.5 合成エラー時にエピソードステータスを `'partial'` に更新（生成済みセグメントを保持）
- [x] 3.6 上記変更のユニットテスト

## 4. 状態管理の更新

- [x] 4.1 `TtsPlaybackState` enum に `waiting` を追加
- [x] 4.2 `_checkAudioState()` を修正：`status == 'partial'` のエピソードも `TtsAudioState.ready` として扱う

## 5. TtsStreamingController の実装

- [x] 5.1 `TtsStreamingController` クラスのスケルトン作成（コンストラクタ、依存注入、内部状態フィールド）
- [x] 5.2 テキストハッシュ検証ロジック実装（SHA-256計算、既存エピソードとの比較、不一致時のデータ削除）
- [x] 5.3 統合起動フロー `start()` の実装（エピソード存在チェック→モード判定→生成ループ起動→再生ループ起動）
- [x] 5.4 Producer-Consumer 協調メカニズム実装（`Completer<void>` の Map を使ったセグメント準備通知）
- [x] 5.5 再生ループ実装（保存済みセグメント再生→未生成セグメント待機→再生の切り替え）
- [x] 5.6 待機状態の管理実装（`TtsPlaybackState.waiting` への遷移とハイライト維持）
- [x] 5.7 `pause()` / `resume()` / `stop()` メソッド実装
- [x] 5.8 停止時のデータ保持ロジック実装（`partial` ステータス更新、Isolate解放、一時ファイルクリーンアップ）
- [x] 5.9 上記各機能のユニットテスト

## 6. UI統合

- [x] 6.1 `TextViewerPanel` の `_startGeneration` / `_startPlayback` を `TtsStreamingController.start()` に統合
- [x] 6.2 `_cancelGeneration` を `TtsStreamingController.stop()` に置き換え
- [x] 6.3 `_buildTtsControls` を更新：`partial` エピソードで再生ボタン表示、`waiting` 状態でローディング表示
- [x] 6.4 エピソード切り替え時のストリーミング停止処理の実装
- [x] 6.5 UI変更のウィジェットテスト

## 7. 最終確認

- [x] 7.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [x] 7.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 7.3 `fvm flutter analyze`でリントを実行
- [x] 7.4 `fvm flutter test`でテストを実行
