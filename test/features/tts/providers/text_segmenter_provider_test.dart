import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/text_segmenter.dart';
import 'package:novel_viewer/features/tts/providers/text_segmenter_provider.dart';

void main() {
  group('textSegmenterProvider', () {
    test('returns the same TextSegmenter instance across reads', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final first = container.read(textSegmenterProvider);
      final second = container.read(textSegmenterProvider);

      expect(first, isA<TextSegmenter>());
      expect(identical(first, second), isTrue,
          reason: 'singleton — Riverpod should cache the value');
    });
  });
}
