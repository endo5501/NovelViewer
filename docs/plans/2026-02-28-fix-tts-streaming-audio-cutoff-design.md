# Fix TTS Streaming Audio Cutoff Between Segments

## Problem

When playing TTS audio continuously (streaming mode), sentences are cut off before finishing. The audio transitions to the next segment prematurely.

### Root Cause

`just_audio`'s `play()` returns immediately when `playing` is already `true` (line 939: `if (playing) return;`). During continuous playback, `playing` stays `true` after the first segment, so subsequent `play()` calls are no-ops. The actual playback trigger becomes `setFilePath` → `_player.open(playable, play: _playing)` in `just_audio_media_kit`, which auto-plays because `_playing` is `true`.

This causes two issues:
1. The previous segment's audio output buffer may not be fully flushed before the next segment starts
2. Playback control bypasses `play()` entirely, relying on media_kit auto-play

### Why Edit Mode Works

In edit mode, users typically play individual segments via `playSegment()`. With no next segment to transition to, audio plays to completion naturally.

## Solution

Call `stop()` after each segment completes, before loading the next one. This resets `playing` to `false`, ensuring:
- The audio output buffer is flushed
- `setFilePath` loads without auto-play (`play: false`)
- `play()` functions correctly (sends a real play request)

## Changes

### TtsStreamingController (`_startPlayback` loop)

After `playCompleter.future` resolves and `playSub` is cancelled, call `await _audioPlayer.stop()` before proceeding to the next segment.

### TtsEditController (`playSegment`)

After `playCompleter.future` resolves and `playSub` is cancelled, call `await _audioPlayer.stop()` before returning. This ensures `playAll` transitions cleanly between segments.

### Tests

Verify that fake audio players correctly handle the `stop()` → `setFilePath()` → `play()` sequence in continuous playback scenarios.
