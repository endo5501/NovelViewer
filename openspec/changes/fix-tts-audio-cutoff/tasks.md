## 1. コア実装（stop() → pause() + バッファドレイン遅延）

- [x] 1.1 `TtsStreamingController`のバッファドレイン遅延デフォルト値を500msから800msに変更し、実機テストで音声途切れが解消されるか確認する
- [x] 1.2 `TtsStreamingController`のデバッグログ（`debugPrint`）を全て除去する（`Stopwatch`、`[TTS] seg=`で始まるログ全て）
- [x] 1.3 `tts_adapters.dart`（`JustAudioPlayer`）のデバッグログ（`debugPrint`による`[TtsAudio]`ログ）を除去する
- [x] 1.4 `TtsStreamingController`から不要になった`import 'package:flutter/foundation.dart'`を除去する（debugPrint除去後に不要であれば）

## 2. テスト

- [x] 2.1 `tts_streaming_controller_test.dart`の全テストが通過することを確認する
- [x] 2.2 `tts_edit_controller_test.dart`の全テストが通過することを確認する（`pause()`変更の検証含む）
- [x] 2.3 `fvm flutter test`で全テストスイートが通過することを確認する

## 3. 実機検証

- [ ] 3.1 Windowsで閲覧画面のストリーミング再生を実行し、セグメント間の音声途切れが解消されたことを確認する
- [ ] 3.2 編集画面の「全再生」でセグメント間の音声途切れが解消されたことを確認する
- [ ] 3.3 800msで不十分な場合はデフォルト値を調整する（最大1000ms目安）

## 4. ドキュメント整理

- [x] 4.1 旧設計ドキュメント`docs/plans/2026-02-28-fix-tts-streaming-audio-cutoff-design.md`を新しい知見（pause()使用、バッファドレイン遅延）で更新する

## 5. 最終確認

- [x] 5.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [x] 5.2 codexスキルを使用して現在開発中のコードレビューを実施（/codexで再実施済み）
- [x] 5.3 `fvm flutter analyze`でリントを実行
- [x] 5.4 `fvm flutter test`でテストを実行
