# 上流 issue ドラフト（llfbandit/record）

**投稿済み**: https://github.com/llfbandit/record/issues/617 （2026-07-20）

---

**Title**: [Windows] WAV recordings have a mismatched `data` chunk offset and 36 bytes of stale header debris

**Body**:

## Summary

On Windows, `AudioEncoder.wav` produces a WAV file whose `data` chunk header does not match where the audio actually starts. The declared payload begins 36 bytes before the real PCM data, and the tail of the sink writer's original header is left inside the file as if it were audio.

Most players tolerate this, so it goes unnoticed — but stricter parsers either reject the file or decode 36 bytes of header bytes as samples, producing a click at the very start of the recording.

## Environment

- `record_windows` 2.2.2 (current latest)
- Windows desktop
- `RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1)`

## Steps to reproduce

```dart
final recorder = AudioRecorder();
await recorder.start(
  const RecordConfig(
    encoder: AudioEncoder.wav,
    sampleRate: 16000,
    numChannels: 1,
  ),
  path: outputPath,
);
// ...record for a few seconds...
await recorder.stop();
```

Then inspect the first 96 bytes of the resulting file.

## Actual output

File size: 155540 bytes.

```
offset  bytes
------  ------------------------------------------------
0x0000  52 49 46 46 6a 5f 02 00 57 41 56 45 66 6d 74 20   RIFF....WAVEfmt
0x0010  12 00 00 00 01 00 01 00 80 3e 00 00 00 7d 00 00   fmt size=18, PCM, 1ch, 16000Hz
0x0020  02 00 10 00 00 00 64 61 74 61 42 5f 02 00 00 00   ...data size=155458
0x0030  66 6d 74 20 12 00 00 00 01 00 01 00 80 3e 00 00   fmt  <- again
0x0040  00 7d 00 00 02 00 10 00 00 00 64 61 74 61 42 5f   ...data <- again
0x0050  02 00 00 00 ...                                    real PCM starts at 0x52
```

The header written by `FillWavHeader` is 46 bytes and says the `data` payload starts at offset 46. The actual PCM starts at offset 82 (`155540 - 82 = 155458`, exactly the declared size). Between them sit 36 bytes: the tail of the header the Media Foundation sink writer had written.

## Expected output

A single, consistent header where the `data` chunk offset and size describe the actual PCM payload.

## Cause

`FillWavHeader` in `windows/mediatype/record_mediatype.cpp` writes its own `WAV_FILE_HEADER` layout starting at offset 0:

```cpp
struct WAV_FILE_HEADER
{
    RIFFCHUNK    FileHeader;
    DWORD        fccWaveType;
    RIFFCHUNK    WaveHeader;
    WAVEFORMATEX WaveFormat;
    RIFFCHUNK    DataHeader;
};   // 46 bytes with an 18-byte WAVEFORMATEX
```

```cpp
if (!WriteFile(hFile, (BYTE*)&header, sizeof(WAV_FILE_HEADER), &cbWritten, NULL))
```

This assumes the header that `MFCreateSinkWriterFromURL` already wrote is also 46 bytes. In practice it is 82 bytes, so overwriting only the first 46 leaves the remaining 36 in place — and every offset in the new header is now wrong by that amount.

The intent of `FillWavHeader` (patching in the final sizes once `Finalize()` has run and the payload length is known) is right; the problem is that it rewrites the whole layout at offset 0 instead of patching the size fields in place at the offsets the sink writer actually used.

## Suggested fix

Rather than assuming the header length, walk the chunks the sink writer wrote and update the `RIFF` and `data` size fields where they actually are. That leaves the sink writer's layout intact and keeps the file consistent regardless of what header length Media Foundation chose for a given media type.

## Impact

We hit this in a Flutter desktop app that feeds recorded audio to a native TTS engine as reference audio. Our parser walks the RIFF chunks and, on reaching the declared end of `data`, read the leftover bytes as the next chunk header — a bogus id with a huge size — and failed. We have since made the parser tolerant, but the recording still carries ~1.1ms of near-full-scale noise at the start, because those 36 stale header bytes (`fmt ` = 0x6D66 = 28006, ≈0.85 full scale as int16) are decoded as samples.
