# Fix TTS Streaming Audio Cutoff Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix audio being cut off between segments during continuous TTS playback by calling `stop()` between segments to reset `playing` state.

**Architecture:** `just_audio`'s `play()` is a no-op when `playing` is already `true`. During continuous playback, `playing` stays `true` after the first segment completes, so subsequent `play()` calls do nothing. Adding `stop()` between segments resets `playing` to `false`, ensuring `play()` sends a real platform play request and preventing media_kit from auto-playing via `setFilePath`.

**Tech Stack:** Flutter, just_audio, just_audio_media_kit, Riverpod

---

### Task 1: Write failing test for TtsStreamingController

**Files:**
- Modify: `test/features/tts/data/tts_streaming_controller_test.dart:218-228`

**Step 1: Update `_BehaviorSubjectAudioPlayer.play()` to simulate just_audio's play guard**

Make the fake player more realistic: `play()` returns immediately when `isPlaying` is already `true` (matching `just_audio`'s `if (playing) return;`), and `isPlaying` stays `true` after completion (matching `just_audio`'s behavior where `playing` remains `true` after audio ends).

```dart
  @override
  Future<void> play() async {
    // Simulate just_audio: play() is a no-op when playing is already true.
    // In just_audio 0.9.46, line 939: if (playing) return;
    if (isPlaying) return;
    isPlaying = true;
    playedFiles.add(currentFilePath!);
    _emit(TtsPlayerState.playing);
    Future.delayed(const Duration(milliseconds: 10), () {
      if (isPlaying && !isDisposed) {
        // Note: in just_audio, playing stays true after completion.
        // stop() must be called to reset playing to false.
        _emit(TtsPlayerState.completed);
      }
    });
  }
```

Changes from current code:
1. Add `if (isPlaying) return;` guard at the top
2. Remove `isPlaying = false;` from the completion callback

**Step 2: Run test to verify it fails**

Run: `fvm flutter test test/features/tts/data/tts_streaming_controller_test.dart --name "plays all segments without skipping with BehaviorSubject stream"`

Expected: FAIL (timeout — `play()` is a no-op for segments 2+, so `playCompleter.future` never resolves)

**Step 3: Commit failing test**

```bash
git add test/features/tts/data/tts_streaming_controller_test.dart
git commit -m "test: make BehaviorSubject fake player simulate just_audio play guard

The fake player now returns immediately from play() when isPlaying
is already true, and keeps isPlaying true after completion. This
matches just_audio 0.9.46 behavior and exposes the audio cutoff bug
in continuous playback."
```

---

### Task 2: Fix TtsStreamingController

**Files:**
- Modify: `lib/features/tts/data/tts_streaming_controller.dart:301-305`

**Step 1: Add `stop()` call after segment playback completes**

After `playSub.cancel()`, add `await _audioPlayer.stop()` to reset `playing` state. Guard with `!_stopped` to avoid calling stop on an already-disposed player.

Current code (lines 301-305):
```dart
      await playCompleter.future;
      _activePlayCompleter = null;
      await playSub.cancel();

      if (_stopped) break;
```

New code:
```dart
      await playCompleter.future;
      _activePlayCompleter = null;
      await playSub.cancel();

      // Reset playing state so the next play() sends a real platform request.
      // Without this, just_audio's play() returns immediately (no-op) because
      // playing remains true after completion, and setFilePath auto-plays
      // via media_kit before the previous audio buffer is fully flushed.
      if (!_stopped) {
        await _audioPlayer.stop();
      }

      if (_stopped) break;
```

**Step 2: Run tests to verify they pass**

Run: `fvm flutter test test/features/tts/data/tts_streaming_controller_test.dart`

Expected: ALL PASS

**Step 3: Commit**

```bash
git add lib/features/tts/data/tts_streaming_controller.dart
git commit -m "fix: call stop() between TTS segments to prevent audio cutoff

just_audio's play() is a no-op when playing is already true.
During continuous playback, playing stays true after completion,
so subsequent play() calls did nothing. The actual playback was
triggered by setFilePath's auto-play via media_kit, which could
cut off the previous segment's audio output buffer.

Adding stop() between segments resets playing to false, ensuring
play() sends a real platform play request."
```

---

### Task 3: Write failing test for TtsEditController playAll

**Files:**
- Modify: `test/features/tts/data/tts_edit_controller_test.dart`

**Step 1: Add a realistic fake player class after existing `FakeAudioPlayer`**

```dart
/// Fake player that simulates just_audio's play() guard behavior.
/// play() is a no-op when isPlaying is already true, and isPlaying
/// stays true after completion (matching just_audio 0.9.46).
class RealisticFakeAudioPlayer implements TtsAudioPlayer {
  final _stateController = StreamController<TtsPlayerState>.broadcast();
  String? currentFilePath;
  bool isDisposed = false;
  bool isPlaying = false;
  final playedFiles = <String>[];

  @override
  Stream<TtsPlayerState> get playerStateStream => _stateController.stream;

  @override
  Future<void> setFilePath(String path) async {
    currentFilePath = path;
  }

  @override
  Future<void> play() async {
    if (isPlaying) return;
    isPlaying = true;
    playedFiles.add(currentFilePath!);
    _stateController.add(TtsPlayerState.playing);
    Future.microtask(() {
      if (isPlaying && !isDisposed) {
        _stateController.add(TtsPlayerState.completed);
      }
    });
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
    _stateController.add(TtsPlayerState.paused);
  }

  @override
  Future<void> stop() async {
    isPlaying = false;
    _stateController.add(TtsPlayerState.stopped);
  }

  @override
  Future<void> dispose() async {
    isDisposed = true;
    _stateController.close();
  }
}
```

**Step 2: Write test for playAll with realistic player**

Add after the existing `playAll` group (around line 600):

```dart
    group('playAll with realistic player', () {
      test('plays all segments when stop is called between segments', () async {
        final episodeId = await repository.createEpisode(
          fileName: 'test.txt',
          sampleRate: 24000,
          status: 'completed',
        );
        await repository.insertSegment(
          episodeId: episodeId,
          segmentIndex: 0,
          text: 'セグメント0。',
          textOffset: 0,
          textLength: 6,
          audioData: _makeWavBytes(),
          sampleCount: 5,
        );
        await repository.insertSegment(
          episodeId: episodeId,
          segmentIndex: 1,
          text: 'セグメント1。',
          textOffset: 6,
          textLength: 6,
          audioData: _makeWavBytes(),
          sampleCount: 5,
        );
        await repository.insertSegment(
          episodeId: episodeId,
          segmentIndex: 2,
          text: 'セグメント2。',
          textOffset: 12,
          textLength: 6,
          audioData: _makeWavBytes(),
          sampleCount: 5,
        );

        final isolate = FakeTtsIsolate();
        final player = RealisticFakeAudioPlayer();
        final controller = TtsEditController(
          ttsIsolate: isolate,
          audioPlayer: player,
          repository: repository,
          tempDirPath: tempDir.path,
        );

        await controller.loadSegments(
          text: 'セグメント0。セグメント1。セグメント2。',
          fileName: 'test.txt',
          sampleRate: 24000,
        );

        await controller.playAll();

        expect(player.playedFiles, hasLength(3));
      });
    });
```

**Step 3: Run test to verify it fails**

Run: `fvm flutter test test/features/tts/data/tts_edit_controller_test.dart --name "plays all segments when stop is called between segments"`

Expected: FAIL (timeout — `play()` is a no-op for segments 2+)

**Step 4: Commit failing test**

```bash
git add test/features/tts/data/tts_edit_controller_test.dart
git commit -m "test: add playAll test with realistic player simulating play guard

Tests that playAll works when the audio player's play() is a no-op
for already-playing state (matching just_audio 0.9.46 behavior)."
```

---

### Task 4: Fix TtsEditController

**Files:**
- Modify: `lib/features/tts/data/tts_edit_controller.dart:298-301`

**Step 1: Add `stop()` call after segment playback completes**

Current code (lines 298-301):
```dart
    await _audioPlayer.play();
    await playCompleter.future;
    _activePlayCompleter = null;
    await playSub.cancel();
```

New code:
```dart
    await _audioPlayer.play();
    await playCompleter.future;
    _activePlayCompleter = null;
    await playSub.cancel();
    await _audioPlayer.stop();
```

**Step 2: Run tests to verify they pass**

Run: `fvm flutter test test/features/tts/data/tts_edit_controller_test.dart`

Expected: ALL PASS

**Step 3: Commit**

```bash
git add lib/features/tts/data/tts_edit_controller.dart
git commit -m "fix: call stop() after segment playback to enable playAll transitions

Same root cause as the streaming controller fix: just_audio's play()
is a no-op when playing is already true. Adding stop() after each
segment ensures playAll transitions work correctly."
```

---

### Task 5: Final verification

**Step 1: Run all TTS tests**

Run: `fvm flutter test test/features/tts/`

Expected: ALL PASS

**Step 2: Run full test suite**

Run: `fvm flutter test`

Expected: ALL PASS

**Step 3: Run lint**

Run: `fvm flutter analyze`

Expected: No issues

---

## 5. 最終確認

- [ ] 5.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [ ] 5.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 5.3 `fvm flutter analyze`でリントを実行
- [ ] 5.4 `fvm flutter test`でテストを実行
