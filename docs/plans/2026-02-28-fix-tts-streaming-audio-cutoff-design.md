# Fix TTS Streaming Audio Cutoff Between Segments

## Problem

When playing TTS audio continuously (streaming mode), sentences are cut off before finishing. The audio transitions to the next segment prematurely.

### Root Cause

The actual root cause is a timing mismatch across the audio stack:

1. mpv's `eof-reached` fires when the **decoder** finishes reading the file
2. This propagates through media_kit → just_audio_media_kit → just_audio as a `completed` state
3. However, WASAPI (Windows audio output) still has buffered samples (~200-500ms) to play
4. Any player operation (`stop()`, `setFilePath()` for next segment) at this point kills the remaining buffered audio

Additionally, `just_audio`'s `play()` has a guard: `if (playing) return;` (line 939). After segment completion, `playing` stays `true`, so subsequent `play()` calls are no-ops unless `stop()` or `pause()` is called to reset the flag.

### Why Edit Mode's Single Playback Worked

In edit mode, users typically play individual segments via `playSegment()`. With no next segment to load immediately, the WASAPI buffer drains naturally.

### Why `stop()` Was Wrong

The initial fix called `stop()` between segments. However, `stop()` in just_audio calls `_setPlatformActive(false)`, which **destroys and recreates** the MediaKitPlayer. This kills the WASAPI output buffer immediately, causing the same audio cutoff.

## Solution

Use `pause()` (not `stop()`) after a buffer drain delay:

1. After `completed` state is received, wait for the WASAPI buffer to drain (500ms delay)
2. Call `pause()` to reset `_playing` to `false` without destroying the platform
3. Proceed with `setFilePath()` for the next segment (no auto-play since `_playing` is `false`)
4. Call `play()` which now works correctly (sends a real play request)

`pause()` is lightweight — it sets `_playing = false` and calls `_platform.pause()` without destroying the MediaKitPlayer instance.

## Changes

### TtsStreamingController

- Added `bufferDrainDelay` constructor parameter (default 500ms, injectable as `Duration.zero` for tests)
- After `playCompleter.future` resolves and `playSub` is cancelled:
  1. Wait `_bufferDrainDelay` for audio output buffer to drain
  2. Call `await _audioPlayer.pause()` to reset `_playing` flag

### TtsEditController (`playSegment`)

- Changed `await _audioPlayer.stop()` to `await _audioPlayer.pause()` at end of `playSegment()`
- This ensures `playAll()` transitions cleanly between segments without killing buffered audio

### JustAudioPlayer (`tts_adapters.dart`)

- Simplified `playerStateStream` mapping (removed debug logging, use method reference)

### Tests

- All `TtsStreamingController` test constructors pass `bufferDrainDelay: Duration.zero` to avoid test timeouts
- BehaviorSubject test verifies all segments play without skipping when `pause()` resets the `playing` flag
