## Why

qwen3-tts.cppによるTTS読み上げ機能で、1文目は正常に読み上げられるが2文目以降が再生されないバグが存在する。また、TTS使用後にアプリを終了するとクラッシュする。これらは`TtsPlaybackController`における`just_audio`の`play()`メソッドのブロッキング動作に起因するレースコンディションと、`TtsIsolate`のネイティブリソース解放が不適切であることが原因。

## What Changes

- `TtsPlaybackController._writeAndPlay()`で`await _audioPlayer.play()`がplayback完了までブロックするため、`_startPrefetch()`が再生完了後にしか呼ばれない問題を修正。`_onPlaybackCompleted`から呼ばれた`_synthesizeCurrentSegment`と`_startPrefetch`がレースコンディションを起こし、2文目の合成結果がprefetchとして誤って格納され再生されない。
- `TtsIsolate.dispose()`が`Isolate.kill(priority: Isolate.immediate)`で即座にIsolateを強制終了するため、FFI経由でネイティブ合成エンジンが動作中に中断され、リソースが不正な状態で残りアプリ終了時にクラッシュする問題を修正。

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `tts-playback`: playbackパイプラインのprefetch機構のレースコンディション修正、および`TtsIsolate`のgraceful shutdown実装

## Impact

- `lib/features/tts/data/tts_playback_controller.dart` — `_writeAndPlay`のawait構造を変更し、prefetchのタイミングを修正
- `lib/features/tts/data/tts_isolate.dart` — `dispose()`でIsolateのgraceful shutdownを実装
- `lib/features/tts/data/tts_adapters.dart` — `JustAudioPlayer`にplay開始後即座に制御を返す仕組みが必要な場合は修正
- `test/features/tts/data/tts_playback_controller_test.dart` — 2文目以降の再生に関するテスト追加
- `test/features/tts/data/tts_isolate_test.dart` — graceful shutdown関連のテスト追加
