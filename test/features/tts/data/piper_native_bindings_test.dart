import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/piper_native_bindings.dart';

void main() {
  group('PiperNativeBindings', () {
    test('libraryName returns correct name for macOS', () {
      if (Platform.isMacOS) {
        expect(PiperNativeBindings.libraryName, 'libpiper_plus.dylib');
      }
    });

    test('libraryName returns correct name for Windows', () {
      if (Platform.isWindows) {
        expect(PiperNativeBindings.libraryName, 'piper_plus.dll');
      }
    });

    test('throws on unsupported platform', () {
      if (!Platform.isMacOS && !Platform.isWindows && !Platform.isIOS) {
        expect(
          () => PiperNativeBindings.libraryName,
          throwsA(isA<UnsupportedError>()),
        );
      }
    });

    test('libraryName matches libraryNameFor on the running platform', () {
      if (Platform.isMacOS || Platform.isWindows) {
        expect(
          PiperNativeBindings.libraryName,
          PiperNativeBindings.libraryNameFor(Platform.operatingSystem),
        );
      }
    });
  });

  group('PiperNativeBindings.libraryNameFor', () {
    test('macOS opens the bundled dylib', () {
      expect(
        PiperNativeBindings.libraryNameFor('macos'),
        'libpiper_plus.dylib',
      );
    });

    test('Windows opens the DLL beside the executable', () {
      expect(PiperNativeBindings.libraryNameFor('windows'), 'piper_plus.dll');
    });

    test('iOS opens the binary inside the embedded framework', () {
      expect(
        PiperNativeBindings.libraryNameFor('ios'),
        'piper_plus.framework/piper_plus',
      );
    });

    test('any other platform is unsupported', () {
      for (final os in ['linux', 'android', 'fuchsia']) {
        expect(
          () => PiperNativeBindings.libraryNameFor(os),
          throwsA(isA<UnsupportedError>()),
          reason: os,
        );
      }
    });
  });

  // The expected values are sizeof() of the structs in upstream piper-plus
  // v2.0.2's piper_plus.h (PIPER_PLUS_API_VERSION 1), measured on a 64-bit
  // target. A mismatch means the Dart layout drifted from the C header, and
  // every create/synthesize call would read or write the wrong bytes.
  group('piper_plus.h struct layout', () {
    test('PiperPlusConfig matches the C struct size', () {
      expect(sizeOf<PiperPlusConfig>(), 72);
    });

    test('PiperPlusSynthOptions matches the C struct size', () {
      expect(sizeOf<PiperPlusSynthOptions>(), 56);
    });

    test('PiperPlusPhonemeResult matches the C struct size', () {
      expect(sizeOf<PiperPlusPhonemeResult>(), 40);
    });
  });

  group('PiperNativeBindings - shared library', () {
    PiperNativeBindings? openBuiltLibrary() {
      if (!Platform.isMacOS) return null;
      final libPath =
          '${Directory.current.path}/macos/Frameworks/libpiper_plus.dylib';
      if (!File(libPath).existsSync()) return null;
      return PiperNativeBindings(DynamicLibrary.open(libPath));
    }

    test('all C API symbols are accessible from the shared library', () {
      final bindings = openBuiltLibrary();
      if (bindings == null) return;

      // Accessing each late-final function lookup should not throw (verifies
      // the symbol exists in the compiled shared library).
      expect(bindings.apiVersion, isNotNull);
      expect(bindings.getLastError, isNotNull);
      expect(bindings.create, isNotNull);
      expect(bindings.free, isNotNull);
      expect(bindings.defaultOptions, isNotNull);
      expect(bindings.synthesize, isNotNull);
      expect(bindings.freeAudio, isNotNull);
      expect(bindings.sampleRate, isNotNull);
      expect(bindings.languageId, isNotNull);
      expect(bindings.phonemize, isNotNull);
    });

    test('the built library reports C API version 1', () {
      final bindings = openBuiltLibrary();
      if (bindings == null) return;

      expect(bindings.apiVersion(), 1);
    });

    test('default options round-trip through the struct by value', () {
      final bindings = openBuiltLibrary();
      if (bindings == null) return;

      final opts = bindings.defaultOptions();

      // Upstream defaults documented in piper_plus.h.
      expect(opts.speakerId, 0);
      expect(opts.languageId, -1);
      expect(opts.noiseScale, closeTo(0.4, 1e-6));
      expect(opts.lengthScale, closeTo(1.0, 1e-6));
      expect(opts.noiseW, closeTo(0.5, 1e-6));
      expect(opts.sentenceSilenceSec, closeTo(0.2, 1e-6));
      expect(opts.speakerEmbedding, nullptr);
      expect(opts.speakerEmbeddingDim, 0);
    });
  });
}
