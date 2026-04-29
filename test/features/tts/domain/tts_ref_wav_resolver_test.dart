import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/domain/tts_ref_wav_resolver.dart';

void main() {
  group('TtsRefWavResolver.resolve', () {
    test('null storedPath returns fallbackPath', () {
      expect(
          TtsRefWavResolver.resolve(
              storedPath: null, fallbackPath: '/voice/default.wav'),
          '/voice/default.wav');
    });

    test('empty storedPath returns null (explicit "no reference")', () {
      expect(
          TtsRefWavResolver.resolve(
              storedPath: '', fallbackPath: '/voice/default.wav'),
          isNull);
    });

    test('non-empty storedPath returns it as-is', () {
      expect(
          TtsRefWavResolver.resolve(
              storedPath: '/voice/custom.wav',
              fallbackPath: '/voice/default.wav'),
          '/voice/custom.wav');
    });

    test('null storedPath and null fallbackPath returns null', () {
      expect(
          TtsRefWavResolver.resolve(
              storedPath: null, fallbackPath: null),
          isNull);
    });

    test('non-empty storedPath is passed through resolver when supplied', () {
      String resolver(String name) => '/voices/$name';
      expect(
          TtsRefWavResolver.resolve(
              storedPath: 'custom.wav',
              fallbackPath: '/voice/default.wav',
              resolver: resolver),
          '/voices/custom.wav');
    });

    test('null storedPath ignores resolver and returns fallback', () {
      String resolver(String name) => '/voices/$name';
      expect(
          TtsRefWavResolver.resolve(
              storedPath: null,
              fallbackPath: '/voice/default.wav',
              resolver: resolver),
          '/voice/default.wav');
    });

    test('empty storedPath ignores resolver and returns null', () {
      String resolver(String name) => '/voices/$name';
      expect(
          TtsRefWavResolver.resolve(
              storedPath: '',
              fallbackPath: '/voice/default.wav',
              resolver: resolver),
          isNull);
    });
  });
}
