import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/audiocpp_native_bindings.dart';

void main() {
  group('AudiocppNativeBindings', () {
    test('libraryName returns correct name for macOS', () {
      if (Platform.isMacOS) {
        expect(AudiocppNativeBindings.libraryName, 'libaudiocpp_ffi.dylib');
      }
    });

    test('libraryName returns correct name for Windows', () {
      if (Platform.isWindows) {
        expect(AudiocppNativeBindings.libraryName, 'audiocpp_ffi.dll');
      }
    });

    test('throws on unsupported platform', () {
      if (!Platform.isMacOS && !Platform.isWindows) {
        expect(
          () => AudiocppNativeBindings.libraryName,
          throwsA(isA<UnsupportedError>()),
        );
      }
    });
  });

  group('AudiocppNativeBindings - symbol lookup', () {
    test('all C API symbols are accessible from the shared library', () {
      if (!Platform.isMacOS) return;

      final libPath =
          '${Directory.current.path}/macos/Frameworks/libaudiocpp_ffi.dylib';
      if (!File(libPath).existsSync()) return;

      final library = DynamicLibrary.open(libPath);
      final bindings = AudiocppNativeBindings(library);

      // Accessing each late-final function lookup should not throw (verifies
      // the symbol exists in the compiled shared library).
      expect(bindings.createAbortHandle, isNotNull);
      expect(bindings.freeAbortHandle, isNotNull);
      expect(bindings.abort, isNotNull);
      expect(bindings.resetAbort, isNotNull);
      expect(bindings.init, isNotNull);
      expect(bindings.isLoaded, isNotNull);
      expect(bindings.free, isNotNull);
      expect(bindings.synthesize, isNotNull);
      expect(bindings.getAudio, isNotNull);
      expect(bindings.getAudioLength, isNotNull);
      expect(bindings.getSampleRate, isNotNull);
      expect(bindings.getError, isNotNull);
    });
  });
}
