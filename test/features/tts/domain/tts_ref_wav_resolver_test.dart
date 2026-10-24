import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/domain/tts_ref_wav_resolver.dart';

void main() {
  group('TtsRefWavResolver.resolve', () {
    test('null storedPath returns fallbackPath', () {
      expect(
        TtsRefWavResolver.resolve(
          storedPath: null,
          fallbackPath: '/voice/default.wav',
          resolver: null,
          acceptedExtensions: null,
        ),
        '/voice/default.wav',
      );
    });

    test('empty storedPath returns null (explicit "no reference")', () {
      expect(
        TtsRefWavResolver.resolve(
          storedPath: '',
          fallbackPath: '/voice/default.wav',
          resolver: null,
          acceptedExtensions: null,
        ),
        isNull,
      );
    });

    test('non-empty storedPath returns it as-is', () {
      expect(
        TtsRefWavResolver.resolve(
          storedPath: '/voice/custom.wav',
          fallbackPath: '/voice/default.wav',
          resolver: null,
          acceptedExtensions: null,
        ),
        '/voice/custom.wav',
      );
    });

    test('null storedPath and null fallbackPath returns null', () {
      expect(
        TtsRefWavResolver.resolve(
          storedPath: null,
          fallbackPath: null,
          resolver: null,
          acceptedExtensions: null,
        ),
        isNull,
      );
    });

    test('non-empty storedPath is passed through resolver when supplied', () {
      String resolver(String name) => '/voices/$name';
      expect(
        TtsRefWavResolver.resolve(
          storedPath: 'custom.wav',
          fallbackPath: '/voice/default.wav',
          resolver: resolver,
          acceptedExtensions: null,
        ),
        '/voices/custom.wav',
      );
    });

    test('null storedPath ignores resolver and returns fallback', () {
      String resolver(String name) => '/voices/$name';
      expect(
        TtsRefWavResolver.resolve(
          storedPath: null,
          fallbackPath: '/voice/default.wav',
          resolver: resolver,
          acceptedExtensions: null,
        ),
        '/voice/default.wav',
      );
    });

    test('empty storedPath ignores resolver and returns null', () {
      String resolver(String name) => '/voices/$name';
      expect(
        TtsRefWavResolver.resolve(
          storedPath: '',
          fallbackPath: '/voice/default.wav',
          resolver: resolver,
          acceptedExtensions: null,
        ),
        isNull,
      );
    });
    group('a stored file the engine cannot read is treated as none', () {
      String resolver(String name) => '/voices/$name';

      test('a segment\'s MP3 is dropped where only WAVE is accepted', () {
        expect(
          TtsRefWavResolver.resolve(
            storedPath: 'narrator.mp3',
            fallbackPath: '/voices/default.wav',
            resolver: resolver,
            acceptedExtensions: const {'.wav'},
          ),
          isNull,
        );
      });

      test('the fallback is not used in its place', () {
        // The segment chose a voice; replacing it with the global one would
        // speak in a voice nobody picked for this segment.
        expect(
          TtsRefWavResolver.resolve(
            storedPath: 'narrator.MP3',
            fallbackPath: '/voices/default.wav',
            resolver: resolver,
            acceptedExtensions: const {'.wav'},
          ),
          isNull,
        );
      });

      test('an accepted file is resolved as before', () {
        expect(
          TtsRefWavResolver.resolve(
            storedPath: 'narrator.wav',
            fallbackPath: null,
            resolver: resolver,
            acceptedExtensions: const {'.wav'},
          ),
          '/voices/narrator.wav',
        );
      });

      test('a null set accepts every file', () {
        expect(
          TtsRefWavResolver.resolve(
            storedPath: 'narrator.mp3',
            fallbackPath: null,
            resolver: resolver,
            acceptedExtensions: null,
          ),
          '/voices/narrator.mp3',
        );
      });
    });
  });
}
