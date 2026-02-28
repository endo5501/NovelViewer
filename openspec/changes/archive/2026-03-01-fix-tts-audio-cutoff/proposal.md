## Why

TTS連続再生（ストリーミングモード・編集画面の全セグメント再生）において、セグメントの音声が最後まで再生される前に次のセグメントへ遷移し、文末が途切れる問題が発生している。根本原因は、just_audio/media_kit/WASAPIの3層にまたがるオーディオバッファ管理の不整合にある。mpvの`eof-reached`（デコーダ完了）イベントはWindowsオーディオデバイス（WASAPI）のバッファドレインより先に発火するため、完了検知後に即座にプレイヤーを操作すると残りの音声出力が失われる。現在、暫定的な500ms遅延とpause()による修正が適用されているが、デバッグログの除去・遅延値の最適化・設計ドキュメントの更新が必要。

## What Changes

- セグメント間のバッファドレイン遅延（`bufferDrainDelay`）を`TtsStreamingController`のコンストラクタパラメータとして正式に導入し、テスト時にゼロ遅延を注入可能にする
- セグメント完了後の`stop()`呼び出しを`pause()`に置換し、just_audioの`_playing`フラグをリセットしつつプラットフォーム（MediaKitPlayer）を維持する
- `TtsEditController.playSegment()`末尾の`stop()`も`pause()`に変更し、`playAll()`でのセグメント間遷移を正常化する
- 開発用デバッグログ（`debugPrint`）を除去する
- バッファドレイン遅延のデフォルト値を実機テストに基づいて最適化する（現在500ms、ユーザーフィードバックでは僅かに途切れが残る）
- 旧設計ドキュメント（`docs/plans/2026-02-28-fix-tts-streaming-audio-cutoff-design.md`）を新しい知見で更新する

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `tts-streaming-pipeline`: セグメント完了後のオーディオバッファドレインとプレイヤー状態リセットの要件を追加。`stop()`ではなく`pause()`を使用し、バッファドレイン遅延を挟む連続再生フローの仕様化。
- `tts-edit-screen`: `playSegment()`完了時のプレイヤー状態リセット方法を`stop()`から`pause()`に変更する要件追加。

## Impact

- **コード**: `TtsStreamingController`（コンストラクタ、`_startPlayback`ループ）、`TtsEditController`（`playSegment`）、`JustAudioPlayer`（デバッグログ除去）
- **テスト**: `tts_streaming_controller_test.dart`（全コンストラクタに`bufferDrainDelay: Duration.zero`追加済み）、`tts_edit_controller_test.dart`（pause()変更の検証）
- **依存関係**: just_audio 0.9.46、just_audio_media_kit 2.1.0、media_kit 1.2.6の内部動作に依存（特にplay()ガード、stop()によるプラットフォーム破壊、eof-reachedイベントのタイミング）
- **プラットフォーム**: 主にWindows（WASAPI）で発生。macOSでの再現は未確認だが、同様のバッファリング遅延が存在する可能性あり
