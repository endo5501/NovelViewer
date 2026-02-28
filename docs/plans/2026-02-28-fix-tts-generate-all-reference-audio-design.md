# Fix TTS Generate-All Reference Audio

## Problem

The TTS edit screen allows users to select a reference audio file per segment.
Individual segment generation works correctly because `_resolveRefWavPath()` in
the dialog resolves filenames to full paths via `VoiceReferenceService`.

However, "generate all" (`generateAllUngenerated()`) passes segment-level
`refWavPath` values (filename-only, e.g., `"data_loading.wav"`) directly to the
C++ engine without resolving them to full paths. The C++ engine's `fopen()` fails
because it receives a relative filename instead of an absolute path.

## Root Cause

In `tts_edit_controller.dart` line 248:

```dart
final refWavPath = switch (segmentRef) {
  null => globalRefWavPath,    // OK: global is already resolved
  '' => null,                   // OK: no reference audio
  _ => segmentRef,              // BUG: filename-only, not resolved
};
```

## Solution

Add a `resolveRefWavPath` callback parameter to `generateAllUngenerated()` so the
controller can resolve segment-level filenames without depending on
`VoiceReferenceService` directly.

### Changes

1. **`tts_edit_controller.dart`**: Add `String? Function(String)? resolveRefWavPath`
   parameter. Use it in the switch expression: `_ => resolveRefWavPath?.call(segmentRef) ?? segmentRef`.

2. **`tts_edit_dialog.dart`**: Pass `voiceService?.resolveVoiceFilePath` as the
   `resolveRefWavPath` callback in `_generateAll()`.

### Impact

- 2 files modified, ~3 lines changed
- No API changes, no breaking changes
- Existing tests for `generateAllUngenerated` need updating to cover the new parameter
