import 'dart:ffi';
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

  group('TtsNativeBindings - setLanguage', () {
    test('setLanguage binding is accessible from shared library', () {
      if (!Platform.isMacOS) return;

      final libPath = '${Directory.current.path}/macos/Frameworks/libqwen3_tts_ffi.dylib';
      if (!File(libPath).existsSync()) return;

      final library = DynamicLibrary.open(libPath);
      final bindings = TtsNativeBindings(library);

      // Accessing setLanguage should not throw (verifies the symbol exists)
      expect(bindings.setLanguage, isNotNull);
    });
  });
}
