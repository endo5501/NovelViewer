import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/tts_native_bindings.dart';

void main() {
  group('TtsNativeBindings', () {
    test('libraryName returns correct name for macOS', () {
      // On macOS, expect .dylib
      if (Platform.isMacOS) {
        expect(TtsNativeBindings.libraryName, 'libqwen3_tts_ffi.dylib');
      }
    });

    test('libraryName returns correct name for Windows', () {
      if (Platform.isWindows) {
        expect(TtsNativeBindings.libraryName, 'qwen3_tts_ffi.dll');
      }
    });

    test('throws on unsupported platform', () {
      if (!Platform.isMacOS && !Platform.isWindows) {
        expect(
          () => TtsNativeBindings.libraryName,
          throwsA(isA<UnsupportedError>()),
        );
      }
    });
  });
}
