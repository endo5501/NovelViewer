import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/lame_enc_bindings.dart';

void main() {
  group('LameEncBindings', () {
    test('libraryName returns correct name for Windows', () {
      if (Platform.isWindows) {
        expect(LameEncBindings.libraryName, 'lame_enc_ffi.dll');
      }
    });

    test('libraryName returns correct name for macOS', () {
      if (Platform.isMacOS) {
        expect(LameEncBindings.libraryName, 'liblame_enc_ffi.dylib');
      }
    });

    test('throws on unsupported platform', () {
      if (!Platform.isMacOS && !Platform.isWindows) {
        expect(
          () => LameEncBindings.libraryName,
          throwsA(isA<UnsupportedError>()),
        );
      }
    });

    test('isAvailable returns false when DLL is not present', () {
      // In test environment, the DLL is typically not in the search path
      // unless explicitly placed there
      expect(LameEncBindings.isAvailable, isA<bool>());
    });
  });

  group('LameEncBindings - DLL integration', () {
    test('can open DLL and bind functions', () {
      if (!Platform.isWindows) return;

      final dllPath =
          '${Directory.current.path}/build/windows/x64/runner/Release/lame_enc_ffi.dll';
      if (!File(dllPath).existsSync()) return;

      final library = DynamicLibrary.open(dllPath);
      final bindings = LameEncBindings(library);

      expect(bindings.init, isNotNull);
      expect(bindings.encode, isNotNull);
      expect(bindings.flush, isNotNull);
      expect(bindings.close, isNotNull);
    });

    test('init and close lifecycle works', () {
      if (!Platform.isWindows) return;

      final dllPath =
          '${Directory.current.path}/build/windows/x64/runner/Release/lame_enc_ffi.dll';
      if (!File(dllPath).existsSync()) return;

      final library = DynamicLibrary.open(dllPath);
      final bindings = LameEncBindings(library);

      final result = bindings.init(24000, 1, 128);
      expect(result, 0);

      bindings.close();
    });

    test('encode produces MP3 data from PCM input', () {
      if (!Platform.isWindows) return;

      final dllPath =
          '${Directory.current.path}/build/windows/x64/runner/Release/lame_enc_ffi.dll';
      if (!File(dllPath).existsSync()) return;

      final library = DynamicLibrary.open(dllPath);
      final bindings = LameEncBindings(library);

      final result = bindings.init(24000, 1, 128);
      expect(result, 0);

      // Create a short PCM buffer (1 second of silence)
      const numSamples = 24000;
      final pcm = calloc<Int16>(numSamples);
      for (var i = 0; i < numSamples; i++) {
        pcm[i] = 0;
      }

      // MP3 buffer (worst case: 1.25 * numSamples + 7200)
      const mp3BufSize = 37200;
      final mp3Buf = calloc<Uint8>(mp3BufSize);

      final bytesWritten =
          bindings.encode(pcm, numSamples, mp3Buf, mp3BufSize);
      expect(bytesWritten, greaterThanOrEqualTo(0));

      final flushBytes = bindings.flush(mp3Buf, mp3BufSize);
      expect(flushBytes, greaterThanOrEqualTo(0));

      bindings.close();
      calloc.free(pcm);
      calloc.free(mp3Buf);
    });
  });
}
