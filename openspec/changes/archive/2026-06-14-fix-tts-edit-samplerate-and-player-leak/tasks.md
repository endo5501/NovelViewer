## 1. F109: エピソードのサンプルレート修正（テストファースト）

- [x] 1.1 `TtsEditController` のテストを追加: `loadSegments(sampleRate: 22050)` 後にセグメント生成でエピソードを作成すると、作成された `tts_episodes.sample_rate` が 22050 になることを検証（コントローラ契約の回帰ガード）
- [x] 1.2 既存の `tts_engine_config_test.dart` が `resolveFromReader(piper)`→22050 / `(qwen3)`→24000 を検証済みであることを確認（`config.sampleRate` の正しさは既存テストで担保。追加テスト不要）
- [x] 1.3 `tts_edit_dialog.dart` の `_initialize` で `ttsEngineTypeProvider` と `TtsEngineConfig.resolveFromRef` を用いてエンジン設定を解決し、`loadSegments(sampleRate: config.sampleRate)` に変更（`24000` 直書きを撤去）。ダイアログのグルー1行はコードレビュー（3.1/3.2）で担保
- [x] 1.4 1.1 のテストがパスすることを確認

## 2. F110: SegmentPlayer の dispose 漏れ修正（テストファースト）

- [x] 2.1 `TtsEditController` のテストを追加: `dispose()` 呼び出しで注入した `SegmentPlayer`（fake/spy）の `dispose()` が呼ばれることを検証（失敗を確認）
- [x] 2.2 dispose順序のテストを追加: `_segmentPlayer.dispose()` が一時ファイル削除より前に呼ばれることを検証
- [x] 2.3 `tts_edit_controller.dart` の `dispose()` に `await _segmentPlayer.dispose()` を追加（一時ファイル削除より前に配置）
- [x] 2.4 2.1/2.2 のテストがパスすることを確認

## 3. 最終確認

- [x] 3.1 code-reviewスキルを使用してコードレビューを実施（指摘1件: dispose時のcleanup順序のエラー耐性 → `finally`化＋回帰テストで対応）
- [x] 3.2 codexスキルを使用して現在開発中のコードレビューを実施（サンプルレート修正は既存設計と整合と確認。隣接する既存リーク経路 F148〈init中early-closeでcontrollerリーク〉を指摘 → 本diffが導入したものではないため別changeへ分離・フォローアップ起票済み）
- [x] 3.3 `fvm flutter analyze`でリントを実行（No issues found）
- [x] 3.4 `fvm flutter test`でテストを実行（全2062件→ハードニング後の編集コントローラ54件含め通過）
